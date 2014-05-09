/**
  This module offers type definitions and facilities for dna molecules representations and manipulations.
*/
module comet.bio.dna;

import std.conv;
import std.exception;
import std.ascii;

/**
  DNA nucleotide representation.
*/
enum Nucleotide {

  ADENINE = 0,
  CYTOSINE = 1,
  GUANINE = 2,
  THYMINE = 3,
  GAP = 4,
  
}

private immutable Nucleotide[ 5 ]               nucleotides = [ std.traits.EnumMembers!Nucleotide ];
private immutable char[ nucleotides.length ]    abbreviations = [ 'a', 'c', 'g', 't', '_' ];
private immutable string[ nucleotides.length ]  names = [ "adenine", "cytosine", "guanine", "thymine", "gap" ];

/**
  Returns the nucleotide whose abbreviation is the one provided.
  Crashes if the string is empty.
  Throws if the abbreviation is unknown.
*/
Nucleotide fromAbbreviation( string abbr ) in {

  assert( abbr.length, "passing null abbreviation to function fromAbbreviation" );
  
} body {
  
  return fromAbbreviation( abbr[ 0 ] );
  
}
///Ditto.
Nucleotide fromAbbreviation( char abbr ) {

  foreach( i, c; abbreviations ) {
  
    if( c == toLower( abbr ) ) { return nucleotides[ i ]; }
    
  }
  
  enforce( false, "uknown abbreviation: " ~ abbr );  
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


import std.typecons;

/**
  Extended abbreviations supporting nucleotide sets.
  Standard here: http://www.bioinformatics.org/sms/iupac.html
*/
private immutable ( Tuple!( char, Nucleotide[] ) )[]               nucleotideSets = 
  [
    tuple( 'a', [ Nucleotide.ADENINE  ] ),
    tuple( 'c', [ Nucleotide.CYTOSINE ] ),
    tuple( 'g', [ Nucleotide.GUANINE  ] ),
    tuple( 't', [ Nucleotide.THYMINE  ] ),
    tuple( '-', [ Nucleotide.GAP      ] ),
    tuple( 'r', [ Nucleotide.ADENINE  , Nucleotide.GUANINE  ] ),
    tuple( 'w', [ Nucleotide.ADENINE  , Nucleotide.THYMINE  ] ),
    tuple( 'm', [ Nucleotide.ADENINE  , Nucleotide.CYTOSINE ] ),
    tuple( 's', [ Nucleotide.GUANINE  , Nucleotide.CYTOSINE ] ),
    tuple( 'k', [ Nucleotide.GUANINE  , Nucleotide.THYMINE  ] ),
    tuple( 'y', [ Nucleotide.CYTOSINE , Nucleotide.THYMINE  ] ),
    tuple( 'b', [ Nucleotide.CYTOSINE , Nucleotide.GUANINE  , Nucleotide.THYMINE  ] ),
    tuple( 'd', [ Nucleotide.ADENINE  , Nucleotide.GUANINE  , Nucleotide.THYMINE  ] ),
    tuple( 'h', [ Nucleotide.ADENINE  , Nucleotide.CYTOSINE , Nucleotide.THYMINE  ] ),
    tuple( 'v', [ Nucleotide.ADENINE  , Nucleotide.CYTOSINE , Nucleotide.GUANINE  ] ),
    tuple( 'n', [ Nucleotide.ADENINE  , Nucleotide.CYTOSINE , Nucleotide.GUANINE  , Nucleotide.THYMINE ] ),
  ];

/**
  Converts a character into its associated nucleotide sets according to the given
  standard: http://www.bioinformatics.org/sms/iupac.html
*/
immutable( Nucleotide[] ) fromExtendedAbbreviation( char abbr ) {
  import std.algorithm: find;

  char lowered = toLower( abbr );

  auto found = nucleotideSets[].find!( pair => pair[ 0 ] == lowered )();
  enforce( found.length, "uknown abbreviation: " ~ abbr );  
  return found[ 0 ][ 1 ];
  
}

unittest {
  import std.algorithm: equal;

  foreach( nucleotideSet; nucleotideSets ) {
    
    auto setFound = fromExtendedAbbreviation( nucleotideSet[ 0 ] );
    assert( equal( setFound, nucleotideSet[ 1 ] ) );    
        
  }
  //Sanity redundant testing.
  assert( equal( fromExtendedAbbreviation( 'a' ), [ Nucleotide.ADENINE ] ) );
  assert( equal( fromExtendedAbbreviation( 'T' ), [ Nucleotide.THYMINE ] ) );
  assert( equal( fromExtendedAbbreviation( 'd' ), [ Nucleotide.ADENINE, Nucleotide.GUANINE, Nucleotide.THYMINE ] ) );
  assert( !equal( fromExtendedAbbreviation( 'k' ), [ Nucleotide.GUANINE, Nucleotide.CYTOSINE ] ) );

}