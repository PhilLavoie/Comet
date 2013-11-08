/**
  Module defining a set of facilities for handling segment pairs in the context
  of parallel sequence processing.
*/  
module comet.segments;

import std.range;
import std.algorithm;
import std.container;

/**
  Returns true if the given type is a valid sequence, false otherwise.
  So far, a valid sequence need to be random access and be able to provide its length.  
*/
private template isSequence( T ) {
  static if( isRandomAccessRange!T && hasLength!T ) {
    enum isSequence = true;
  } else {
    enum isSequence = false;
  }
}

/**
  This structure holds a pair of sequences for the purposes of parallel processing.
  It assumes that both segments be of the same length and satisfy the sequence interface.
*/
public struct SegmentPair( S ) if( isSequence!S ) {
private:
  S _left;  //Left sequence.
  S _right; //Right sequence.
  
  this( S left, S right ) {
    _left = left;
    _right = right;
  }
public:
  @property auto left() { return _left[]; }
  alias first = left;
  @property auto right() { return _right[]; }    
  alias second = right;
}

/**
  Factory functions for constructing a pair of equal length adjacent segments. Note that NO bounds checking is made, 
  It uses a sequence as input. The pair's left segment starts on the index provided and is of the length provided.
  The right segments starts right next to the previous segment's end and is of equal length.
  
  Make sure the sequence have enough elements to generate a valid segment pair.
*/
private auto segmentPairAt( S )( S sequence, size_t start, size_t length ) if( isSequence!S ) {
  auto rightStart = start + length;
  return SegmentPair!S( sequence[ start .. rightStart ], sequence[ rightStart .. rightStart + length ] );
}

/**
  A facility range that iterates over columns in order.
  It requires a range of random access ranges.
*/
struct ColumnsRange( RoR ) if( isInputRange!RoR && isSequence!( ElementType!RoR ) ) {
private:
  RoR _ror;       //Range of ranges holding the random access ranges. In other words, the range of rows.
  size_t _index;  //Current index.

  this( RoR ror ) {
    _ror = ror; 
  }  
public:  
  bool empty() { return _index == _ror.front.length; }
  auto front() { return transversal!( TransverseOptions.assumeNotJagged )( _ror, _index ); }
  void popFront() {
    ++_index;
  }
}
/**
  Factory functions for creating columns range.
*/
private auto columnsRange( RoR )( RoR ror ) if( isInputRange!RoR && isSequence!( ElementType!RoR ) ) {
  return ColumnsRange!RoR( ror );
}

/**
  This structure holds multiple segment pairs in parallel.
  It was made so that the user can easily traverse transversally a group of related
  segment pairs. Note that this structure was meant to be built once, and
  refilled multiple times in order to avoid memory waste.
  
  It is expected that the NUMBER of segment pairs held will be determine at runtime,
  but will never change through the course of the program. Therefore the segment pairs
  holder should be constructed once but refilled multiple times.
*/
struct SegmentPairs( S ) {
private:
  Array!( SegmentPair!( S ) ) _pairs; //The container where the pairs are stored.
  
  this( size_t pairsCount ) {
    _pairs.length = pairsCount;
  }  
  
  /**
    Template function returning the left or right segments held by the pairs
    in a top/bottom fashion. If the range is for the left segments, then:
      The range's first item is the first pair's left segment.
      The second one is the second pair's left segment, etc...
  */
  auto segments( string s )() if( s == "left" || s == "right" ) {
    return _pairs[].map!( pair => mixin( "pair." ~ s ) );
  }  
  
  /**
    Template function returning a range iterating over the
    segments columns from left to right. If the range is for
    the left columns:
      The first element is a range over the left segments first column. 
      The second element is a range over the left segments second column, etc...
    
    This template also provides a range that iterates over both segments columns linearly.
    Take those three pairs:
      [ [ 1, 2, 3,  4, 5, 6    ],
        [ 2, 4, 6,  8, 10, 12  ],
        [ 3, 6, 9,  12, 15, 18 ] ]
    The range will travel left segments on the 0th column first, and then move to the 0th column
    of the right segments. Then it will do the same for the rest of the columns. Generating
    this:
      [ 1, 2, 3, 4, 8, 12 ], [ 2, 4, 6, 5, 10, 15 ], [ 3, 6, 9, 6, 12 18 ].        
    
  */  
  auto columns( string s )() if( s == "left" || s == "right" ) {
    return columnsRange( segments!s );
  }
  auto columns( string s )() if( s == "" ) {
    return columnsRange( chain( leftSegments, rightSegments ) );
  }
  
  alias leftSegments = segments!"left";
  alias rightSegments = segments!"right";
  alias leftColumns = columns!"left";
  alias rightColumns = columns!"right";
  
public:
  /**
    Returns a range over both segments columns.
  */
  alias byColumns = columns!"";
  
  /**
    Reset the sequence of pairs. Make sure you use the same amount as previously.
  */
  void set( Range )( Range sequences, size_t start, size_t length ) if( isSequence!Range && isSequence!( ElementType!Range ) ) {
    size_t i = 0;
    foreach( sequence; sequences ) {
      _pairs[ i ] = segmentPairAt( sequence, start, length );
      ++i;
    }
  }
  
  /**
    Returns a range iterating over the segment pairs.
  */
  auto opSlice() { return _pairs[]; }
  alias pairs = opSlice;
}

/**
  Factory function that creates a segment pairs structure.
  It expects a range of random access ranges.
  It creates a pair of equal length adjacent segments for every sequence at the given index and of the given length.
  The structure returned holds the pair for every sequence passed in the same order they were traversed.
  
  This function should only be called once because it allocates. Reset the segment pairs directly instead of creating
  a new one for new segment pairs.
*/
auto segmentPairsAt( Range )( Range sequences, size_t start, size_t length ) if( isSequence!Range && isSequence!( ElementType!Range ) ) {
  alias Sequence = ElementType!Range;
  auto pairs = SegmentPairs!( Sequence )( sequences.length );
  pairs.set( sequences, start, length );
  return pairs;
} 

unittest {
  import std.conv;
  
  auto sequences = 
    [
      [ 0, 1, 2, 3,   3, 2, 1, 0 ],
      [ 2, 4, 6, 8,   10, 12, 14, 16 ]
    ];
  auto pairs = segmentPairsAt( sequences[], 0, 4 ); 
  auto firstPair = pairs._pairs[ 0 ];
  assert( firstPair.left.equal( [ 0, 1, 2, 3 ] ) );
  assert( firstPair.right.equal( [ 3, 2, 1, 0 ] ) );
  auto secondPair = pairs._pairs[ 1 ];
  assert( secondPair.left.equal( [ 2, 4, 6, 8 ] ) );
  assert( secondPair.right.equal( [ 10, 12, 14, 16 ] ) );

  assert( pairs.leftSegments.equal( [ firstPair.left, secondPair.left ] ) );
  assert( pairs.rightSegments.equal( [ firstPair.right, secondPair.right ] ) );
  
  auto leftColumns = pairs.leftColumns;
  assert( 4 == count( leftColumns ) );
  assert( leftColumns.front.equal( [ 0, 2 ] ) );
  leftColumns.popFront();
  assert( leftColumns.front.equal( [ 1, 4 ] ) );
  leftColumns.popFront();
  assert( leftColumns.front.equal( [ 2, 6 ] ) );
  leftColumns.popFront();
  assert( leftColumns.front.equal( [ 3, 8 ] ) );
  
  auto rightColumns = pairs.rightColumns;
  assert( 4 == count( rightColumns ) );
  assert( rightColumns.front.equal( [ 3, 10 ] ) );
  rightColumns.popFront();
  assert( rightColumns.front.equal( [ 2, 12 ] ) );
  rightColumns.popFront();
  assert( rightColumns.front.equal( [ 1, 14 ] ) );
  rightColumns.popFront();
  assert( rightColumns.front.equal( [ 0, 16 ] ) );
  
  auto columns = pairs.byColumns;  
  assert( 4 == count( columns ) );
  assert( columns.front.equal( [ 0, 2, 3, 10 ] ) );
  columns.popFront();
  assert( columns.front.equal( [ 1, 4, 2, 12 ] ) );
  columns.popFront();
  assert( columns.front.equal( [ 2, 6, 1, 14 ] ) );
  columns.popFront();
  assert( columns.front.equal( [ 3, 8, 0, 16 ] ) );  
}   