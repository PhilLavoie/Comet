module comet.bio.dna;

import std.conv;
import std.exception;
import std.ascii;

enum Nucleotide : uint {
  ADENINE = 0,
  CYTOSINE = 1,
  GUANINE = 2,
  THYMINE = 3,
  GAP = 4,
  ANY = 5
}

private immutable Nucleotide[ 6 ] nucleotides = [ Nucleotide.ADENINE, Nucleotide.CYTOSINE, Nucleotide.GUANINE, Nucleotide.THYMINE, Nucleotide.GAP, Nucleotide.ANY ];
private immutable char[ nucleotides.length ] abbreviations = [ 'a', 'c', 'g', 't', '_', 'n' ];
private immutable string[ nucleotides.length ] names = [ "adenine", "cytosine", "guanine", "thymine", "gap", "any" ];

Nucleotide fromAbbreviation( string abbr ) in {
  assert( abbr !is null, "Passing null abbreviation to function fromAbbreviation" );
} body {
  enforce( abbr.length == 1, "Uknown abbreviation: " ~ abbr );
  return fromAbbreviation( abbr[ 0 ] );
}

Nucleotide fromAbbreviation( char abbr ) {
  foreach( i, c; abbreviations ) {
    if( c == toLower( abbr ) ) { return nucleotides[ i ]; }
  }
  enforce( false, "Uknown abbreviation: " ~ abbr );
  assert( 0 );
}

string name( Nucleotide n ) {
  return names[ n ];
}

char abbreviation( Nucleotide n ) {
  return abbreviations[ n ];
}

unittest {
  auto length = 0;
  foreach( n; __traits( allMembers, Nucleotide ) ) {
    auto nucleotide = mixin( "Nucleotide." ~ n );
    assert( nucleotide.name() == names[ nucleotide ] );
    assert( nucleotide.abbreviation() == abbreviations[ nucleotide ] );
    ++length;
  }
  assert( length == nucleotides.length );
  assert( length == abbreviations.length );
  assert( length == names.length );
  //Sanity redundant testing.
  assert( Nucleotide.ADENINE.name() == "adenine" );
  assert( Nucleotide.ADENINE.abbreviation() == 'a' );
  assert( Nucleotide.GUANINE.name() == "guanine" );
  assert( Nucleotide.GUANINE.abbreviation() == 'g' );
  assert( Nucleotide.CYTOSINE.name() == "cytosine" );
  assert( Nucleotide.CYTOSINE.abbreviation() == 'c' );
  assert( Nucleotide.THYMINE.name() == "thymine" );
  assert( Nucleotide.THYMINE.abbreviation() == 't' );
  assert( Nucleotide.GAP.name() == "gap" );
  assert( Nucleotide.GAP.abbreviation() == '_' );
}

class Sequence {
public:
  this( string id, Nucleotide[] nucleotides = null ) {
    _id = id;
    _nucleotides = nucleotides;
  }
  
  @property string id() { return _id; }
  @property Nucleotide[] nucleotides() { return _nucleotides; }
  @property void nucleotides( Nucleotide[] ns ) { _nucleotides = ns; }
  @property size_t length() { return _nucleotides.length; }
      
  
  ref Nucleotide opIndex( size_t index ) in { 
    assert( index < _nucleotides.length, "index: " ~ index.to!string ~ " beyond maximum boundary: " ~ _nucleotides.length.to!string );
  } body {
    return _nucleotides[ index ];
  }

  override string toString() {
    string dataString = _nucleotides !is null ? ", data: " : "";
    foreach( n; _nucleotides ) {
      dataString ~= n.abbreviation();
    }
    return "Sequence{ id: " ~ _id ~ ", length: " ~ _nucleotides.length.to!string ~ dataString ~ " }";
  }
  
private:
  string _id;
  Nucleotide[] _nucleotides;

}
auto sequence( string id, Nucleotide[] nucleotides ) {
  return new Sequence( id, nucleotides );
}