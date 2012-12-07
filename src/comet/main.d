import comet.sma;
import comet.config;
import comet.algos;

import deimos.bio.dna;
import deimos.containers.tree;
import fasta = deimos.bio.fasta;
alias fasta.Molecule Molecule;

import std.stdio;
import std.algorithm;
import std.conv;
import std.exception;
import std.container;
import std.datetime;

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
    
    SysTime startTime;
    if( cfg.printTime ) { startTime = Clock.currTime(); }
    
    auto bestResults = calculateDuplicationsCosts( sequences, cfg );  
    
    printResults( bestResults );  
    if( cfg.printTime ) { printTime( Clock.currTime() - startTime ); }
    
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

void printTime( Time )( Time time ) {
  writeln( "Execution time in seconds: ", time.total!"seconds", ".", time.fracSec.msecs );
}


auto calculateDuplicationsCosts( Seq )( Seq[] sequences, ref Config cfg ) in {
  assert( 2 <= sequences.length );
} body {  
  //Up to now, only nucleotides are supported.
  Nucleotide[] states = [ Nucleotide.ADENINE, Nucleotide.CYTOSINE, Nucleotide.GUANINE, Nucleotide.THYMINE ];  
  //Basic 0, 1 cost table.
  auto mutationCosts = ( Nucleotide initial, Nucleotide mutated ) { 
    if( initial != mutated ) { return 1; }
    return 0;
  };
  
  auto algorithm = algo( cfg, sequences, states, mutationCosts );
  auto results = Results( cfg.noResults );
  
  //Main loop of the program.
  //For each period length, evaluate de duplication cost of every possible positions.
  size_t seqLength = sequences[ 0 ].length;
  foreach( 
    dup; 
    Duplications( 
      cfg.minPeriod, 
      cfg.maxPeriod, 
      cfg.periodStep, 
      seqLength,
      ( size_t period ){ if( 1 <= cfg.verbosity ) { writeln( "Doing period: ", period ); } } 
    )
  ) {
    algorithm.duplicationCost( dup );
    results.add( dup );
  }
    
  return results[];
}

/**
  A wrapper around a fast, ordered index (as of right now, the structure used is a red black tree).
  It keeps track of how many results were inserted so that it does not go beyond a maximum limit.
  When the limit is reached, if the new result to be inserted is better than the worse one held,
  then the latter is popped from the tree and the former is inserted, maintaining the number of
  results below the limit.
*/
struct Results {
  private RedBlackTree!( Duplication ) _results;
  private size_t _max;
  private size_t _noResults;
  
  this( size_t maxResults ) {
    _results = new typeof( _results )();
    _noResults = 0;
    _max = maxResults;
  }
  
  void add( Duplication result ) {
    if( !_max ) { return; }
    
    //Store result.
    if( _noResults < _max ) {
      _results.insert( result );
      ++_noResults;
    //If we reached the maximum number of results, then we determine
    //if the current duplication result is better than the worst already known.
    //If so, we get rid of the worst and insert the better one.
    } else if( result < _results.back() ){
      _results.removeBack();
      _results.insert( result );
    }
  }

  /**
    Returns a range of results in ascending order (the "lowest" result is actually the best).
  */
  auto opSlice() {
    return _results[];
  }  
}
