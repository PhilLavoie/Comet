module comet.programs;

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


interface ProgramI {
  void run();
} 

template isProgram( alias T ) if( is( T ) ) {
  static if( is( typeof( () { T t; t.run(); } ) ) ) {
    enum isProgram = true;
  } else {
    enum isProgram = false;
  }
}
template isProgram( alias T ) if( !is( T ) ) {
  enum isProgram = isProgram!( typeof( T ) );
}


ProgramI programFor( string[] args ) out( program ) {
  assert( isProgram!program );
} body {
  return normalRun( configFor( args ) );
}






private class NormalRun: ProgramI {
protected:
  Config _cfg;

  this( Config cfg ) {
    _cfg = cfg;
  }
  
public:
  override void run() {
    foreach( file; _cfg.sequencesFiles ) {
      processFile( file, _cfg.resultsFileFor( file ), _cfg,  _cfg.algos.front );
    }  
  }
}

auto normalRun( Config cfg ) {
  return new NormalRun( cfg );
}

private class ReferencesGeneration {

}

private class TestsRun {

}

private class MeasuresCompilation {


}

private void enforceSequencesLength( Range )( Range sequences, size_t length ) if( isForwardRange!Range ) {
  foreach( sequence; sequences ) {
    enforce( sequence.length == length, "Expected sequence: " ~ sequence.id ~ " of length: " ~ sequence.length.to!string ~ " to be of length: " ~ length.to!string );
  }
}

/**
  Extract the sequences from the provided file and makes sure they follow the rules of processing:
    - They must be of fasta format;
    - They must be made of dna nucleotides;
    - They must have the same name.  
*/
private auto loadSequences( File file ) {
  auto sequences = fasta.parse!( Molecule.DNA )( file );
  size_t seqsCount = sequences.length;
  enforce( 2 <= seqsCount, "Expected at least two sequences but read " ~ seqsCount.to!string() );
  
  size_t seqLength = sequences[ 0 ].length;
  enforceSequencesLength( sequences[], seqLength );
  
  return sequences;
}

private void processFile( File seqFile, File resFile, Config cfg, Algo algo ) {
  if( 1 <= cfg.verbosity ) {
    cfg.outFile.writeln( "Processing file " ~ seqFile.name ~ "..." );
  }
  
  
  //Extract sequences from file.
  auto sequences = loadSequences( seqFile );
  size_t seqLength = sequences.length;
  size_t midPosition = seqLength / 2;
  
  //Make sure the minimum period is within bounds.
  enforce( 
    cfg.minPeriod <= midPosition,
    "The minimum period: " ~ cfg.minPeriod.to!string() ~ " is set beyond the midPosition sequence position: " ~ to!string( midPosition ) ~
    " and is therefore invalid."
  );
  
  SysTime startTime;
  
  if( cfg.printTime ) { startTime = Clock.currTime(); }  
  
  auto results = Results( cfg.noResults );  
  
  auto bestResults = sequentialDupCostsCalculation( results, sequences, cfg, algorithmFor( algo, sequences, loadStates(), loadMutationCosts() ) );  
  
  if( cfg.printTime ) { cfg.timeFile.printTime( Clock.currTime() - startTime ); }
  if( cfg.printResults ) { resFile.printResults( bestResults ); }
}

/**
  Prints the results to the standard output in the given order.
*/
private void printResults( Range )( File output, Range results ) if( isForwardRange!Range ) {
  foreach( result; results ) {
    output.writeln( "Duplication{ start: ", result.start, ", period: ", result.period, ", cost: ", result.cost, " }" );
  }
}

/**
  Prints the execution time value to the standard output.
*/
private void printTime( Time )( File output, Time time ) {
  output.writeln( "Execution time in seconds: ", time.total!"seconds", ".", time.fracSec.msecs );
}

private auto loadStates() {
  //Up to now, only nucleotides are supported.
  return [ Nucleotide.ADENINE, Nucleotide.CYTOSINE, Nucleotide.GUANINE, Nucleotide.THYMINE ];  
}

private auto loadMutationCosts() {
  //Basic 0, 1 cost table. Include gaps?
  return ( Nucleotide initial, Nucleotide mutated ) { 
    if( initial != mutated ) { return 1; }
    return 0;
  };
}

private auto loadAlgos( Range, Sequences, States, MutationCosts )( Range algos, Sequences sequences, States states, MutationCosts mCosts ) if( isForwardRange!Range ) {
  import std.algorithm;
  return algos.map!( algo => algorithmFor( algo, sequences, states, mutationCosts ) );
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
private auto sequentialDupCostsCalculation( Seq )( ref Results results, Seq[] sequences, ref Config cfg, AlgoI algorithm ) in {
  assert( 2 <= sequences.length );
} body {  
    
  
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
private struct Results {
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
