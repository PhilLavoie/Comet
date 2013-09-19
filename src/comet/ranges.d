/**
  Module dedicated to loop ranges.
*/
module comet.ranges;

import comet.dup;
import comet.config;

import std.algorithm;

struct Period {
  private size_t _length;
  private size_t _seqLength;
  
  this( size_t length, size_t seqLength ) in {
    assert( 0 < length );
    assert( 0 < seqLength );
  } body {
    _length = length;
    _seqLength = seqLength;
  }
  
  @property auto length() { return _length; }
  
  @property auto duplications() {
    return Duplications( _length, _seqLength );
  }
}

/**
  Range iterating over every period of the given sequences.
*/
struct Periods {
  private size_t _currentPeriod;
  private size_t _maxPeriod;
  private size_t _periodStep;
  private size_t _seqLength;
  
  this( size_t minPeriod, size_t maxPeriod, size_t periodStep, size_t seqLength ) in {
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
  }
  
  @property Period front() { return Period( _currentPeriod, _seqLength ); }  
  @property bool empty() { return _maxPeriod < _currentPeriod; }  
  void popFront() {  _currentPeriod += _periodStep; }  
}

auto periods( in ref Config config, size_t seqLength ) {
  return Periods( config.minPeriod, config.maxPeriod, config.periodStep, seqLength );
}

struct Duplications {
  private size_t _periodLength; //Length of each segments.
  private size_t _currentPos;   //Current index on the sequence where the first segments begin.
  private size_t _maxPos;       //Inclusive.
  
  this( size_t periodLength, size_t seqLength ) in {
    assert( 0 < periodLength );
    assert( 0 < seqLength );
  } body {
    _periodLength = periodLength;
    _currentPos = 0;
    _maxPos = seqLength - ( 2 * _periodLength ); //Invalid: Only makes sense for even sequence lengths.
  }
  
  @property bool empty() { return _maxPos < _currentPos; }
  @property Duplication front() { return Duplication( _currentPos, _periodLength, 0.0 ); }
  void popFront() { ++_currentPos; }
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
  this( size_t start, size_t period ) {
    _current = start;
    _stop = start + period - 1;
  }
  
  @property auto stop() { return _stop; }
  
  @property bool empty() { return _stop < _current; }
  @property size_t front() { return _current; }
  void popFront() { ++_current; }  
}

auto positions( Duplication dup ) {
  return Positions( dup.start, dup.period );
}

