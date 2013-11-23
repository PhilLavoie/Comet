/**
  Module providing facilities related to the fasta format.
*/
module comet.bio.fasta;

import std.exception;
import std.stdio;
import std.algorithm;
import std.string;
import ascii = std.ascii;
import std.array;

import dna = comet.bio.dna;

//TODO move this molecule enumeration to a more generic module -> Possibly with sequences.
enum Molecule {
  DNA,
  RNA
}

private immutable string SEQUENCE_START = ">"; //Every line starting a sequence starts with this character.

/**
  Convenient function that opens the file in the correct mode and delegates to
  the implementation.
*/
auto parse( Molecule m )( string file ) {
  return parse!m( File( file, "r" ) );
}

/**
  Parse the fasta file provided. Throws an exception whenever the format is unrecognized.
  If everything is correct however, the function returns a range containing all extracted
  sequences.
*/
auto parse( Molecule m )( File f ) if( m == Molecule.DNA ) {
  auto sequences = appender!( dna.Sequence[] )();
  
  char[] line;
  f.readln( line );
  while( !f.eof() ) {
    string id = null;
    auto nucleotides = appender!( dna.Nucleotide[] )();  
    //Extract id.
    enforce( line.startsWith( SEQUENCE_START ), "Expected fasta sequence start \"" ~ SEQUENCE_START ~ "\" but found: " ~ line );
    //Extract id.
    id = line[ 1 .. line.countUntil!( ascii.isWhite )() ].idup;    
    enforce( line !is null && 0 < line.strip.length, "Expected sequence if to have at least one meaningful character but found: " ~ id );
    //Extract data.
    while( f.readln( line ) && !line.startsWith( SEQUENCE_START ) ) {
      foreach( c; line ) {
        if( ascii.isWhite( c ) ) { continue; }
        nucleotides.put( dna.fromAbbreviation( c ) );          
      }
    }
    enforce( nucleotides.data !is null, "Empty sequence data for: " ~ id );
    sequences.put( new dna.Sequence( id, nucleotides.data ) );
  }
  
  return sequences.data;
}

unittest {
  
}
