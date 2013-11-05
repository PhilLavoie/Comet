import comet.sma;
import comet.config;
import comet.algos;
import comet.ranges;

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
import std.range: isForwardRange;

//TODO: Add parallel processing optimization.

void main( string[] args ) {
  try {
    //Program configuration. Defaults are defined appropriately and values are set
    //using command line options.
    Config cfg = new Config();
    cfg.parse( args );
  
    foreach( fileRuns; cfg.programRuns ) {
      processFile( fileRuns, cfg );
    }  
    
  } catch( Exception e ) {
    if( e.msg.length ) {
      writeln( e.msg );
    }
    return;
  } 
}

void enforceSequencesLength( Range )( Range sequences, size_t length ) if( isForwardRange!Range ) {
  foreach( sequence; sequences ) {
    enforce( sequence.length == length, "Expected sequence: " ~ sequence.id ~ " of length: " ~ sequence.length.to!string ~ " to be of length: " ~ length.to!string );
  }
}

void processFile( Range )( Range fileRuns, Config cfg ) if( isForwardRange!Range ) {
  auto seqFile = fileRuns.sequencesFile;
  
  if( 1 <= cfg.verbosity ) {
    cfg.outFile.writeln( "Processing file " ~ seqFile.name ~ "..." );
  }
  
  
  //Extract sequences from file.
  auto sequences = fasta.parse!( Molecule.DNA )( seqFile );
  size_t seqsCount = sequences.length;
  enforce( 1 < seqsCount, "Expected at least two sequences but received " ~ seqsCount.to!string() );
  
  size_t seqLength = sequences[ 0 ].length;
  enforceSequencesLength( sequences[], seqLength );
  
  size_t midPosition = seqLength / 2;
  
  //Make sure the minimum period is within bounds.
  enforce( 
    cfg.minPeriod <= midPosition,
    "The minimum period: " ~ cfg.minPeriod.to!string() ~ " is set beyond the midPosition sequence position: " ~ to!string( midPosition ) ~
    " and is therefore invalid."
  );
  
  SysTime startTime;
  
  foreach( run; fileRuns ) {
    if( cfg.printTime ) { startTime = Clock.currTime(); }  
    
    auto bestResults = sequentialDupCostsCalculation( sequences, cfg, run.algorithm );  
    
    if( cfg.printTime ) { cfg.timeFile.printTime( Clock.currTime() - startTime ); }
    if( cfg.printResults ) { run.resultsFile.printResults( bestResults ); }
  }
}

/**
  Prints the results to the standard output in the given order.
*/
void printResults( Range )( File output, Range results ) if( isForwardRange!Range ) {
  foreach( result; results ) {
    output.writeln( "Duplication{ start: ", result.start, ", period: ", result.period, ", cost: ", result.cost, " }" );
  }
}

/**
  Prints the execution time value to the standard output.
*/
void printTime( Time )( File output, Time time ) {
  output.writeln( "Execution time in seconds: ", time.total!"seconds", ".", time.fracSec.msecs );
}

//TODO: add support for multiple threads.
//In order to maximize the benefits of the cache, work separation should be based
//on period length, rather than duplication start.
//Since the processing gets more and more costy as the period length increase,
//a thread pool should be used. Each thread should have their own results, then
//merge them. This would prevent the need to synchronize the structure, introducing
//additional processing only to save space (and god knows this algorithm needs
//speed more than space!).
/**
  Main loop of the program. For each every duplication possible given
  the program configuration, it passes it to the appropriate algorithm to
  calculate its cost. Its cost is stored such that only that the duplications
  with the n best scores are kept (provided by configuration).
  
  Returns a range over the results in descending order (best result comes first).
*/
auto sequentialDupCostsCalculation( Seq )( Seq[] sequences, ref Config cfg, Algo rithm ) in {
  assert( 2 <= sequences.length );
} body {  
  //Up to now, only nucleotides are supported.
  Nucleotide[] states = [ Nucleotide.ADENINE, Nucleotide.CYTOSINE, Nucleotide.GUANINE, Nucleotide.THYMINE ];  
  //Basic 0, 1 cost table. Include gaps?
  auto mutationCosts = ( Nucleotide initial, Nucleotide mutated ) { 
    if( initial != mutated ) { return 1; }
    return 0;
  };
  
  auto results = Results( cfg.noResults );
  auto algorithm = algo( rithm, sequences, states, mutationCosts );
  
  //Main loop of the program.
  //For each period length, evaluate de duplication cost of every possible positions.
  size_t seqLength = sequences[ 0 ].length;
  
  foreach( period; cfg.periods( seqLength ) ) {
    if( 2 <= cfg.verbosity ) { cfg.outFile.writeln( "Doing period: ", period.length ); }
    foreach( dup; period.duplications() ) {
      algorithm.duplicationCost( dup );
      results.add( dup );
    }  
  }
  
  return results[];
}

/*
auto parallelDupCostsCalculation() {
  return void;
}
*/

/**
  A wrapper around a fast, ordered index (as of right now, the structure used is a red black tree).
  It keeps track of how many results were inserted so that it does not go beyond a maximum limit.
  When the limit is reached, if the new result to be inserted is better than the worse one held,
  then the latter is popped from the tree and the former is inserted, satisfying the limit.
*/
struct Results {
  private RedBlackTree!( Duplication ) _results;
  private size_t _max;
  
  /**
    The number of results is intended to be bounded.
    The parameter provided is that bound (inclusive).
  */
  this( size_t maxResults ) {
    _results = new typeof( _results )();
    _max = maxResults;
  }
  
  /**
    Returns the number of results currently stored.
  */
  @property size_t length() { return _results.length; }
  
  /**
    This function adds the result only if:
      - The maximum number of results has not been reached, or
      - The worst duplication known is worse than the result to be
        inserted. In that case, the worst result is exchanged
        with the provided one.
  */
  void add( Duplication result ) {
    if( !_max ) { return; }
    
    //Store result.
    if( _results.length < _max ) {
      _results.insert( result );
    //If we reached the maximum number of results, then we determine
    //if the current duplication result is better than the worst already known.
    //If so, we get rid of the worst and insert the better one.
    } else if( result < _results.back() ){
      _results.removeBack();
      _results.insert( result );
    }
  }

  /**
    Returns a range of results in ascending order (the "lowest" result is the actual best).
  */
  auto opSlice() {
    return _results[];
  } 
  /**
    Returns a range of results in ascending order (the "lowest" result is the actual best).
  */  
  auto range() {
    return _results[];
  }
}
