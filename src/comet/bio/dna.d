/**
  This module offers type definitions and facilities for dna molecules representations and manipulations.
*/
module comet.bio.dna;

import std.conv;
import std.exception;
import std.ascii;

enum Nucleotide {

  ADENINE = 0,
  CYTOSINE = 1,
  GUANINE = 2,
  THYMINE = 3,
  GAP = 4,
  ANY = 5
  
}

private immutable Nucleotide[ 6 ]               nucleotides = [ std.traits.EnumMembers!Nucleotide ];
private immutable char[ nucleotides.length ]    abbreviations = [ 'a', 'c', 'g', 't', '_', 'n' ];
private immutable string[ nucleotides.length ]  names = [ "adenine", "cytosine", "guanine", "thymine", "gap", "any" ];

/**
  Returns the nucleotide whose abbreviation is the one provided.
  Crashes if the string is empty.
  Throws if the abbreviation is unknown.
*/
Nucleotide fromAbbreviation( string abbr ) in {

  assert( abbr.length, "Passing null abbreviation to function fromAbbreviation" );
  
} body {
  
  return fromAbbreviation( abbr[ 0 ] );
  
}
///Ditto.
Nucleotide fromAbbreviation( char abbr ) {

  foreach( i, c; abbreviations ) {
  
    if( c == toLower( abbr ) ) { return nucleotides[ i ]; }
    
  }
  
  enforce( false, "Uknown abbreviation: " ~ abbr );  
  assert( false );
  
}

/**
  Returns the lower case name of the nucleotide: "adenine", "cytosine", ...
*/
string name( Nucleotide n ) {

  return names[ n ];
  
}

/**
  Returns the lower ase abbreviation of the nucleotide: 'a', 'c', 'g', 't'.
*/
char abbreviation( Nucleotide n ) {

  return abbreviations[ n ];
  
}

unittest {

  auto length = 0;
  
  foreach( nucleotide; std.traits.EnumMembers!Nucleotide ) {
    
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