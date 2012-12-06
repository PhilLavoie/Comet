import comet.sma;
import comet.config;
import comet.dup;

import deimos.bio.dna;
import deimos.containers.tree;
import fasta = deimos.bio.fasta;
alias fasta.Molecule Molecule;

import std.stdio;
import std.algorithm;
import std.conv;
import std.exception;
import std.container;

void main( string[] args ) {
  try {
    //Program configuration. Defaults are defined appropriately and values are set
    //using command line options.
    Config cfg;
    cfg.parse( args );
  
    //Extract sequences from file.
    auto sequences = fasta.parse!( Molecule.DNA )( cfg.sequencesFile );
    size_t seqsCount = sequences.length;
    enforce( 1 < seqsCount, "Expected at least two sequences but received " ~ seqsCount.to!string() );
    
    size_t seqLength = sequences[0].length;
    foreach( sequence; sequences ) {
      enforce( sequence.length == seqLength, "Expected sequence: " ~ sequence.id ~ " of length: " ~ sequence.length.to!string ~ " to be of length: " ~ seqLength.to!string );
    }
    size_t midPosition = seqLength / 2;
    
    //Make sure the minimum period is within bounds.
    enforce( 
      cfg.minPeriod <= midPosition,
      "The minimum period: " ~ cfg.minPeriod.to!string() ~ " is set beyond the midPosition sequence position: " ~ to!string( midPosition ) ~
      " and is therefore invalid."
    );
    
    auto bestResults = calculateDuplicationsCosts( sequences, cfg );  
    printResults( bestResults );  
  } catch( Exception e ) {
    writeln( e.msg );
    return;
  } 
}


void printResults( Range )( Range results ) {
  foreach( result; results ) {
    writeln( "Duplication{ start: ", result.start, ", period: ", result.period, ", cost: ", result.cost, "}" );
  }
}