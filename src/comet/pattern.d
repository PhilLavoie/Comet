module comet.pattern;

import std.traits;
import std.range;
import std.algorithm;

//TODO: try to avoid heap usage.

/**
  Patterns identify if two sequences shall produce the
  same duplication cost.
  Creating a pattern for two sequences and comparing them
  will tell wether or not one can use the same cost for
  both.
*/
struct Pattern {
  private size_t[] _data;
  
  /**
    Constructs the pattern and readies it for comparison.
    This is the only way a pattern should be constructed.
  */
  this( Range )( Range data ) if( isInputRange!Range && hasLength!Range ) {
    _data = new size_t[ data.length ];
    this.data( data );
  } 
  this( Range )( Range data ) if( isInputRange!Range && !hasLength!Range ) {
    _data = new size_t[ data.count ];
    this.data( data );
  }
  
  /**
    Returns the length of the pattern.
  */
  @property const size_t length() { return _data.length; }
  /**
    Returns the value held in the given index.
  */
  const size_t opIndex( size_t index ) { return _data[ index ]; }
  
  
  //The important parts.
  private void data( Range )( Range newData ) {
    static if( isArray!( Range ) ) {
      size_t[ typeof( newData[0] ) ] atomIndexes;
    } else {
      size_t[ typeof( newData.front() ) ] atomIndexes;
    }    
    size_t currentIndex = 0;
    size_t dataIndex = 0;
    foreach( atom; newData ) {
      if( atom !in atomIndexes ) {
        atomIndexes[ atom ] = currentIndex;
        ++currentIndex;
      } 
      _data[ dataIndex ] = atomIndexes[ atom ];
      ++dataIndex;
    }
  }
  
  /**
    Returns true if the comparison operator returns 0.
  */
  const bool opEquals( ref const Pattern rhs ) {
    return 0 == this.opCmp( rhs );
  }
  
  /**
    Hashes on the content of the pattern rather than the
    address of the array used. This is done so that if
    two patterns have the same content, they have the same
    hash key.
  */
  const hash_t toHash() {
    hash_t hash; 
    foreach ( size_t index; _data) {
      hash = ( hash * 9 ) + index; 
    }
    return hash;
  }
  
  /**
    Returns 0 if both patterns are equal. Otherwise, it returns the difference
    between this object's value and the right hand side's value for the first index
    where they differ. If both patterns aren't of the same length, then this object's
    length minus the compared pattern's length is returned. Note that this case
    should not even occur. This might be moved to be an assert...
  */
  const int opCmp( ref const Pattern rhs ) {
    if( this.length != rhs.length ) { return this.length - rhs.length; }
        
    for( size_t i = 0; i < _data.length; i++ ) {
      if( rhs[ i ] != this[ i ] ) {
        return this[ i ] - rhs[ i ];
      }
    }
    return 0;
  }
}

unittest {
  import std.conv;

  auto zeData = "toto";
  auto zeData2 = "caca";
  auto pattern = Pattern( zeData );
  auto pattern2 = Pattern( zeData2 );
  assert( pattern == pattern2, "Comparison returns: " ~ to!string( pattern.opCmp( pattern2 ) ) );  
  assert( pattern.toHash() == pattern2.toHash() );
}