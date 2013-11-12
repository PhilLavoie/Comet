/**
  Module defining a set of facilities for handling segment pairs in the context
  of parallel sequence processing.
*/  
module comet.segments;

import std.range;
import std.algorithm;
import std.container;
import std.typecons;

mixin template Length( string structName ) {
  import std.string;
  import std.uni;
  mixin( 
    "struct " ~ structName ~ " {
      private size_t _value;
      public mixin Proxy!_value;  
      public @property auto value() { return _value; }
      
      this( size_t length ) {
        
        _value = length;
        
      }
      
      this( int length ) in {
        
        debug {
          
          assert( 1 <= length );
          
        }
        
      } body {
      
        _value = length;
        
      }
      
      debug {
      
        invariant() {
        
          assert( 1 <= _value );
          
        }
        
      } 
    }
    auto " ~ toLower( structName[ 0 .. 1 ] )  ~ structName[ 1 .. $ ] ~ "( T... )( T args ) {
    
      return " ~ structName ~ "( args );
    
    }"
  );
}

mixin Length!"SequenceLength";
mixin Length!"SegmentsLength";
mixin Length!"MinLength";
mixin Length!"MaxLength";
mixin Length!"LengthStep";

/**
  Generates all the possible segment length for segment pairs with the given parameters.
  The length applies to a single segment, not to the whole pair.
  Therefore, a range of 100 elements can have segments of length 0 ... 50 inclusively
  (a pair of 50 element segments takes the whole range).
*/
struct SegmentLengthsRange 
{
private:
  size_t _currentLength;  //The current length generated.
  size_t _maxLength;      //Inclusive.
  size_t _lengthStep;     //The jump between lengths. Not necessarily one.
  
  /**
    Creates a segment length range with the given parameters. Both boundaries are inclusive.
  */
  this
  ( 
    SequenceLength sequenceLength, 
    MinLength minLength, 
    MaxLength maxLength, 
    LengthStep lengthStep 
  ) 
  in 
  {
    debug
    {
      assert( 2 <= sequenceLength );    
      assert( minLength <= maxLength );
      assert( minLength % lengthStep == 0 ); //Relax this constraint??
    }
  } 
  body 
  {
    _currentLength = minLength.value;
    _maxLength = min( sequenceLength.value / 2, maxLength.value );
    _lengthStep = lengthStep.value;    
  }
  
  /**
    Returns the inclusive maximum boundary.
  */
  auto inclusiveMaxLength() 
  { 
    return _maxLength; 
  }
  
  /**
    Returns the exclusive maximum boundary.
  */
  auto exclusiveMaxLength() 
  { 
    return _maxLength + 1; 
  }
  
public:
  @property auto front() { return segmentsLength( _currentLength ); }  
  @property bool empty() { return _maxLength < _currentLength; }  
  void popFront() {  _currentLength += _lengthStep; }      
}
/**
  Factory function for constructing a segment length range.
*/
auto segmentLengthsFor( SequenceLength sequenceLength, MinLength minLength, MaxLength maxLength, LengthStep lengthStep ) 
{
  return SegmentLengthsRange( sequenceLength, minLength, maxLength, lengthStep );
}  

unittest 
{
  debug {
    import std.stdio;
    writeln( "running tests for segments length range..." );
    scope( success ) {
      writeln( "done" );
    }
    scope( failure ) {
      writeln( "failed" );
    }
  }
  
  auto minLength = 3u;
  auto maxLength = size_t.max;
  auto lengthStep = 3u;
  auto sequenceLength = 100u;
  
  auto segmentLengths = 
    segmentLengthsFor( 
      SequenceLength( sequenceLength ), 
      MinLength( minLength ), 
      MaxLength( maxLength ), 
      LengthStep( lengthStep ) 
    );
  assert( segmentLengths.inclusiveMaxLength == 50 );
  
  auto index = 0u;
  foreach( length; segmentLengths ) {
    assert( length == minLength + index * lengthStep );
    assert( length <= sequenceLength / 2 );
    ++index;
  }  
}

/**
  This range generates all of the segment pairs possible on a given range of ranges with each segment
  being of the specified length. The first pair starts at index 0 and the last pair
  stops at position sequenceLength - ( 2 * segmentsLength ). So, for a range in which each range has 101 elements and 
  both segments have a length of 50, the last position where pairs will be created is on 101 - 100 = 1. This boundary
  is inclusive.
*/
struct SegmentPairsRange( RoR ) 
{
private:
  RoR _sequences;             //The range of ranges.
  size_t _segmentsLength;     //The length of every segment held by the associated segment pairs.
  size_t _currentPairStart;   //The current position (inclusive) on which starts the leftmost segment.
  size_t _lastPairStart;      //The last position (inclusive) on which starts the leftmost segment of the last segment pairs.
  

  /**
    Creates a range constructing all the pairs with segments of the given length.
  */
  this( RoR sequences, SegmentsLength length ) 
  {
    _sequences = sequences;    
    _segmentsLength = length.value;
    _currentPairStart = 0;    //Starts on the beginning of the sequence.
    _lastPairStart = _sequences.front.length - ( 2 * _segmentsLength );
  }  
  
public:
  @property bool empty() { return _lastPairStart < _currentPairStart; }
  @property auto front() { return segmentPairsAt( _sequences, _currentPairStart, _segmentsLength ); }
  void popFront() { ++_currentPairStart; }
}
/**
  Returns a segment pairs range that generate all segments pairs of the given length for the given sequences.
*/
auto segmentPairsForLength( RoR )( RoR sequences, SegmentsLength length ) {
  return SegmentPairsRange!RoR( sequences, length );
}

unittest {
  //TODO: find good unittests????
}


/**
  This structure holds multiple segment pairs in parallel.
  It was made so that the user can easily traverse transversally a group of related
  segment pairs. For example:
  
      Segment pairs of length 3 at position 3
                    columns
              left           right
              0  1   2     0   1   2
   0,  1, |  2,  3,  4, |  5,  6,  7, |  8,  9, 
  10, 11, | 12, 13, 14, | 15, 16, 17, | 18, 19
  20, 21, | 22, 23, 24, | 25, 26, 27, | 28, 29

  The traversal of the first column of this segment pairs would yield: [ 2, 12, 22, 5, 15, 15 ].  
*/
struct SegmentPairs( E ) 
{
private:
  alias Sequences = E[][];
  
  Sequences _sequences;
  size_t _segmentsLength;                      
  size_t _leftSegmentStart;
  size_t _rightSegmentStart;
    
  this( Sequences sequences, size_t pairsStart, size_t segmentsLength ) 
  in
  {
    debug 
    {
      import std.conv;
      import std.stdio;
      scope( failure ) {
        writeln( typeof( this ).stringof ~ "( " ~ sequences.to!string() ~ ", " ~ pairsStart.to!string() ~ ", " ~ segmentsLength.to!string() ~ " )" );        
      }
      
      assert( sequences.length );
      assert( sequences.front.length );
      assert( sequences.front.length >= ( pairsStart + ( 2  * segmentsLength ) ) );
      assert( 1 <= segmentsLength );
    }
  } 
  body
  {
    _sequences = sequences;
    _leftSegmentStart = pairsStart;
    _segmentsLength = segmentsLength;
    _rightSegmentStart = _leftSegmentStart + _segmentsLength;
  }  
    
  /**
    Template function returning a range iterating over the
    segments columns from left to right. 
    This template provides a range that iterates over both segments columns linearly.
    Take those three pairs:
      [ [ 1, 2, 3,  4, 5, 6    ],
        [ 2, 4, 6,  8, 10, 12  ],
        [ 3, 6, 9,  12, 15, 18 ] ]
    The range will travel left segments on the 0th column first, and then move to the 0th column
    of the right segments. Then it will do the same for the rest of the columns. Generating
    this:
      [ 1, 2, 3, 4, 8, 12 ], [ 2, 4, 6, 5, 10, 15 ], [ 3, 6, 9, 6, 12 18 ].        
    
  */  
  auto columns() { return columnsRange(); }
  
  auto columnsRange() { return ColumnsRange( _sequences, _leftSegmentStart, _segmentsLength ); }
  
public:
   
  struct ColumnsRange 
  {
  private:
    Sequences _sequences;
    size_t _currentColumn;  //Current column index.     
    size_t _segmentsLength;
    size_t _rightSegmentsStart;
    
    this( Sequences sequences, size_t leftSegmentsStart, size_t segmentsLength ) {
      _sequences = sequences;
      _currentColumn = leftSegmentsStart;
      _segmentsLength = segmentsLength;
      _rightSegmentsStart = _currentColumn + _segmentsLength;
    }
    
    private auto column( R )( R range, size_t index ) {
      return Column!R( range, index );
    }
  public:
    auto front() { return this[ 0 ]; }
    auto back() { return this[ $ - 1 ]; }
    //popBack?
    auto empty() { return !length; }
    void popFront() { ++_currentColumn;  }
    
    auto opIndex( size_t index ) { 
      index += _currentColumn;
      return column( chain( transversal( _sequences, index ), transversal( _sequences, index + _segmentsLength ) ), index ); 
    }
    auto opDollar() { return _rightSegmentsStart - _currentColumn; }    
    alias length = opDollar;
    
    struct Column( R ) if( is( ElementType!R == E ) && isInputRange!R ) {
    private:
      R _range;
      size_t _index;
      this( R range, size_t index ) { _range = range; _index = index; }    
    public:
      auto index() { return _index; }
      auto front() { return _range.front; }
      void popFront() { _range.popFront(); }
      auto empty() { return _range.empty; }
    }
  
  }
    
  /**
    Returns a range over both segments columns.
  */
  alias byColumns = columns;
  
  auto segmentsLength() {
    return _segmentsLength;
  }
  
  auto leftSegmentStart() {
    return _leftSegmentStart;
  }  
  
  auto rightSegmentStart() {
    return _rightSegmentStart;
  }
}

/**
  Factory function that creates a segment pairs structure.
  It expects a range of random access ranges.
  It creates a pair of equal length adjacent segments for every sequence at the given index and of the given length.
  The structure returned holds the pair for every sequence passed in the same order they were traversed.
  
  This function should only be called once because it allocates. Reset the segment pairs directly instead of creating
  a new one for new segment pairs.
*/
private auto segmentPairsAt( E )( E[][] sequences, size_t start, size_t length ) {
  return SegmentPairs!E( sequences, start, length );
} 

unittest 
{
  debug {
    import std.stdio;
    writeln( "running tests for segment pairs range..." );
    scope( success ) {
      writeln( "done" );
    }
    scope( failure ) {
      writeln( "failed" );
    }
  }
  import std.conv;
 
  static void assertExpected( R1, R2 )( R1 column, R2 expected, SegmentsLength segLength, size_t segStart ) {
    assert( 
      column.equal( expected ), 
      "length: " ~ segLength.value.to!string() ~ 
      " segment pairs at: " ~ segStart.to!string() ~ 
      " column: " ~ column.index.to!string() ~ 
      " held: " ~ column.to!string() ~ 
      " but expected: " ~ expected.to!string() 
    );  
  }
 
  auto sequences = 
    [ [ 0, 1,  2,  3,    3,  2,  1,  0 ],
      [ 2, 4,  6,  8,   10, 12, 14, 16 ],
      [ 4, 7, 10, 13,   13, 10,  7,  4 ] ];
      
  foreach( segLength; segmentLengthsFor( sequenceLength( sequences[].front.length ), minLength( 1 ), maxLength( 100u ), lengthStep( 1 ) ) ) {
    
    int[] expected;
    
    switch( segLength.value ) {
    
      case 1:
        
        auto segPairsForLength = sequences.segmentPairsForLength( segLength );
        assert( 7 == count( segPairsForLength ) );
        foreach( segPairs; segPairsForLength ) {
          
          auto columns = segPairs.byColumns;
          assert( 1 == count( columns ) );
          auto column = columns.front;
          assert( column.index == segPairs.leftSegmentStart );
          
          switch( segPairs.leftSegmentStart ) {
          
            case 0:            
              
              expected = [ 0, 2, 4, 1, 4, 7 ];              
              break;
              
            case 1:
              
              expected = [ 1, 4, 7, 2, 6, 10 ];              
              break;
              
            case 2:
              
              expected = [ 2, 6, 10, 3, 8, 13 ];              
              break;
              
            case 3:
              
              expected = [ 3, 8, 13, 3, 10, 13 ];                          
              break;
              
            case 4:
              
              expected = [ 3, 10, 13, 2, 12, 10 ];              
              break;
              
            case 5:
              
              expected = [ 2, 12, 10, 1, 14, 7 ];              
              break;
              
            case 6:
              
              expected = [ 1, 14, 7, 0, 16, 4 ];              
              break;
              
            default:
            
              assert( false );        
              
          }
          
          assertExpected( column, expected, segLength, segPairs.leftSegmentStart );             
          
        } 
        
        break;
        
      case 2:    
        auto segPairsForLength = sequences.segmentPairsForLength( segLength );
        assert( 5 == count( segPairsForLength ) );
        foreach( segPairs; segPairsForLength ) 
        {
          auto columns = segPairs.byColumns;
          assert( 2 == count( columns ) );
                    
          switch( segPairs.leftSegmentStart )
          {
            case 0:            
              foreach( column; columns ) 
              {
                switch( column.index ) 
                {
                  case 0:
                    expected = [ 0, 2, 4, 2, 6, 10 ];
                    break;
                  case 1:
                    expected = [ 1, 4, 7, 3, 8, 13 ];
                    break;
                  default:
                    assert( false );               
                }
                assertExpected( column, expected, segLength, segPairs.leftSegmentStart );             
              }              
              break;
              
            case 1:
              foreach( column; columns ) 
              {
                switch( column.index ) 
                {
                  case 1:
                    expected = [ 1, 4, 7, 3, 8, 13 ];
                    break;
                  case 2:
                    expected = [ 2, 6, 10, 3, 10, 13 ];
                    break;
                  default:
                    assert( false );               
                }
                assertExpected( column, expected, segLength, segPairs.leftSegmentStart );             
              }              
              break;          

            case 2:
              foreach( column; columns ) 
              {
                switch( column.index ) 
                {
                  case 2:
                    expected = [ 2, 6, 10, 3, 10, 13 ];
                    break;
                  case 3:
                    expected = [ 3, 8, 13, 2, 12, 10 ];
                    break;
                  default:
                    assert( false );               
                }
                assertExpected( column, expected, segLength, segPairs.leftSegmentStart );             
              }              
              break;          

            case 3:
              foreach( column; columns ) 
              {
                switch( column.index ) 
                {
                  case 3:
                    expected = [ 3, 8, 13, 2, 12, 10 ];
                    break;
                  case 4:
                    expected = [ 3, 10, 13, 1, 14, 7 ];
                    break;
                  default:
                    assert( false );               
                }
                assertExpected( column, expected, segLength, segPairs.leftSegmentStart );             
              }              
              break;          

            case 4:
              foreach( column; columns ) 
              {
                switch( column.index ) 
                {
                  case 4:
                    expected = [ 3, 10, 13, 1, 14, 7 ];
                    break;
                  case 5:
                    expected = [ 2, 12, 10, 0, 16, 4 ];
                    break;
                  default:
                    assert( false );               
                }
                assertExpected( column, expected, segLength, segPairs.leftSegmentStart );             
              }              
              break; 
              
            default:
              assert( false );             
          }          
        }     
        break;

      case 3:
        auto segPairsForLength = sequences.segmentPairsForLength( segLength );
        assert( 3 == count( segPairsForLength ) );
        foreach( segPairs; segPairsForLength ) 
        {
          auto columns = segPairs.byColumns;
          assert( 3 == count( columns ) );
                    
          switch( segPairs.leftSegmentStart )
          {
            case 0:
              foreach( column; columns ) 
              {
                switch( column.index ) 
                {
                  case 0:
                    expected = [ 0, 2, 4, 3, 8, 13 ];
                    break;
                  case 1:
                    expected = [ 1, 4, 7, 3, 10, 13 ];
                    break;                  
                  case 2:
                    expected = [ 2, 6, 10, 2, 12, 10 ];
                    break;
                  default:
                    assert( false );               
                }
                assertExpected( column, expected, segLength, segPairs.leftSegmentStart );             
              }              
              break; 
              
            case 1:
              foreach( column; columns ) 
              {
                switch( column.index ) 
                {
                  case 1:
                    expected = [ 1, 4, 7, 3, 10, 13 ];
                    break;                  
                  case 2:
                    expected = [ 2, 6, 10, 2, 12, 10 ];
                    break;
                  case 3:
                    expected = [ 3, 8 , 13, 1, 14, 7 ];
                    break;
                  default:
                    assert( false );               
                }
                assertExpected( column, expected, segLength, segPairs.leftSegmentStart );             
              }              
              break; 
              
            case 2: 
              foreach( column; columns ) 
              {
                switch( column.index ) 
                {
                  case 2:
                    expected = [ 2, 6, 10, 2, 12, 10 ];
                    break;
                  case 3:
                    expected = [ 3, 8 , 13, 1, 14, 7 ];
                    break;
                  case 4:
                    expected = [ 3, 10, 13, 0, 16, 4 ];
                    break;
                  default:
                    assert( false );               
                }
                assertExpected( column, expected, segLength, segPairs.leftSegmentStart );             
              }              
              break; 
              
            default:
              assert( false );             
          }          
        }     
        break;
            
      case 4:
        auto segPairsForLength = sequences.segmentPairsForLength( segLength );
        assert( 1 == count( segPairsForLength ) );
        foreach( segPairs; segPairsForLength ) 
        {
          auto columns = segPairs.byColumns;
          assert( 4 == count( columns ) );
                    
          switch( segPairs.leftSegmentStart )
          {
            case 0:
              foreach( column; columns ) 
              {
                switch( column.index ) 
                {
                  case 0:
                    expected = [ 0, 2, 4, 3, 10, 13 ];
                    break;
                  case 1:
                    expected = [ 1, 4, 7, 2, 12, 10 ];
                    break;                  
                  case 2:
                    expected = [ 2, 6, 10, 1, 14, 7 ];
                    break;
                  case 3:
                    expected = [ 3, 8, 13, 0 , 16, 4 ];
                    break;
                  default:
                    assert( false );               
                }
                assertExpected( column, expected, segLength, segPairs.leftSegmentStart );             
              }              
              break;              
            default:
              assert( false );             
          }          
        }     
        break;
      
      default:
        assert( false );   
    }  
  }
  
  //With an odd number of elements per sequence.
  sequences = 
    [ [ 0,  1,  2,  3,    3,  2,  1,  0,   -1 ],
      [ 2,  4,  6,  8,   10, 12, 14, 16,   18 ],
      [ 4,  7, 10, 13,   13, 10,  7,  4,    1 ],
      [ 6, 10, 14, 18,   22, 26, 30, 34,   38 ] ];
  auto sequencesLength = sequences[ 0 ].length;
  
  auto segLengths = segmentLengthsFor( sequenceLength( sequences[].front.length ), minLength( 1 ), maxLength( size_t.max ), lengthStep( 1 ) );
  assert( ( sequencesLength / 2 ) == count( segLengths ) );
  
  foreach( segLength; segLengths ) {
    auto segPairsForLength = sequences.segmentPairsForLength( segLength );
    assert( ( sequencesLength - ( 2 * segLength ) + 1 ) == count( segPairsForLength ) );
    
    int leftSegmentStart = 0;  
    foreach( segPairs; segPairsForLength ) {
      assert( segPairs.leftSegmentStart == leftSegmentStart );
      assert( segPairs.segmentsLength == segLength );
      assert( segPairs.rightSegmentStart == leftSegmentStart + segLength );
      
      
      auto columns = segPairs.columns;
      auto noColumns = segLength;
      assert( noColumns == count( columns ) );
      
      int columnIndex = leftSegmentStart;
      foreach( column; columns ) {
        assert( 8 == count( column ) );
        assert( columnIndex == column.index );
        auto xPected = chain( transversal( sequences, columnIndex ), transversal( sequences, columnIndex + segLength ) );
        assertExpected( column, xPected, segLength, leftSegmentStart );             
        ++columnIndex;
      }
      ++leftSegmentStart;
    }  
  }
  
}