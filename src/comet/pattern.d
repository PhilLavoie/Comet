module comet.pattern;

struct Pattern {
  private size_t[] _data;
  
  this( Atom )( Atom[] data ) {
    this.data( data );
  }  
  
  private void resize( size_t newLength ) {
    if( _data is null ) { 
      _data = new size_t[ newLength ]; 
    } else { 
      _data.length = newLength; 
    }
  }
  
  @property size_t length() { return _data.length; }
  size_t opIndex( size_t index ) { return _data[ index ]; }
  
  
  //The important parts.
  @property void data( Atom )( Atom[] newData ) {
    size_t[ Atom ] atomIndexes;
    size_t currentIndex = 0;
    size_t dataIndex = 0;
    resize( newData.length );
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
  bool opEquals( Pattern rhs ) {
    return 0 == this.opCmp( rhs );
  }
  
  int opCmp( Pattern rhs ) {
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