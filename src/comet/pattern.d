module comet.pattern;

struct Pattern {
  private size_t[] _data;
  
  @property size_t length() { return _data.length; }
  size_t opIndex( size_t index ) { return _data[ index ]; }
  //The important parts.
  @property void data( Atom )( Atom[] newData ) {
    size_t[ Atom ] atomIndexes;
    size_t currentIndex = 0;
    size_t dataIndex = 0;
    _data.length = newData.length;
    foreach( atom; newData ) {
      if( atom !in atomIndexes ) {
        atomIndexes[ atom ] = currentIndex;
        ++currentIndex;
      } 
      _data[ dataIndex ] = atomIndexes[ atom ];
      ++dataIndex;
    }
  }
  
  int opCmp( Pattern rhs ) {
    assert( rhs.length == this.length );
    
    for( size_t i = 0; i < _data.length; i++ ) {
      if( rhs[ i ] != this[ i ] ) {
        return this[ i ] - rhs[ i ];
      }
    }
    return 0;
  }
}