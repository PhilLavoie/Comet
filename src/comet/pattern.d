module comet.pattern;

import std.traits;

struct Pattern {
  private size_t[] _data;
  
  this( Range )( Range data ) {
    _data = new size_t[ data.length ];
    this.data( data );
  }  
  
  @property const size_t length() { return _data.length; }
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
  
  const hash_t toHash() {
    hash_t hash; 
    foreach ( size_t index; _data) {
      hash = ( hash * 9 ) + index; 
    }
    return hash;
  }
  
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
}