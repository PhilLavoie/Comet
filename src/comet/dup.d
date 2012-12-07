/**
  Module responsible for everything regarding the calculation of duplications cost.
  It acts as the "inner loop" of the main program.
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
  
  @property size_t stop() { return _start + _period - 1; }
  @property size_t start() { return _start; }
  @property size_t period() { return _period; }
  @property auto positions() {
    return Positions( this.start, this.stop );
  }
  
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
  
  @property auto stop() { return _stop; }
  
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

