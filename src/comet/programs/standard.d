module comet.programs.standard;

debug( modules ) {

  pragma( msg, "compiling " ~ __MODULE__ );

}

//Extract the command name immediately.
import cli = comet.cli.all;

import comet.configs.standard;  //TODO: for some reason, importing this in the function scope creates linker problems....
import comet.configs.probing;   //TODO: ditto.
import comet.configs.algos;

import comet.sma.all;
import comet.results;

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


void run( string[] args ) {
      
  run( cli.commandName( args ), args[ 1 .. $ ] );

}

/**
  Main entry point of the program.
*/
package void run( string command, string[] args ) {

  //Standard mode starts with probing.    
  auto mode = probe( args );
  
  /*
    The processing is done in three steps:
      - Identify the mode;
      - Use the appropriate command line parser and extract the configuration;
      - Load the appropriate program logic and launch the processing with the given config.
  */
  final switch( mode ) {
  
    case Mode.standard:
      
      auto cfg = parse( command, args );
      run( cfg );
    
      break;
      
    case Mode.generateReferences:
    case Mode.compareResults:
    case Mode.runTests:
    case Mode.compileMeasures:
      assert( false, "unimplemented yet" ); 
  
  }

}

private auto resultsFileFor( Config cfg, File file ) {

  return cfg.resultsFile;

}

package void run( Config cfg ) {

  processFile( cfg.sequencesFile, cfg.resultsFileFor( cfg.sequencesFile ), cfg,  cfg.algos.front );

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
  size_t seqLength = sequences[ 0 ].length;
  size_t midPosition = seqLength / 2;
  
  //Make sure the minimum period is within bounds.
  enforce( 
    cfg.minLength <= midPosition,
    "The minimum period: " ~ cfg.minLength.to!string() ~ " is set beyond the mid sequence position: " ~ to!string( midPosition ) ~
    " and is therefore invalid."
  );
  
  SysTime startTime;
  
  //Transfer the sequences into a nucleotides matrix.  
  auto nucleotides = new Nucleotide[][ sequences.length ];
  for( int i = 0; i < nucleotides.length; ++i ) {
  
    nucleotides[ i ] = sequences[ i ].nucleotides;
    
  }
  
  if( cfg.printTime ) { startTime = Clock.currTime(); }  
  
  auto results = Results( cfg.noResults );  
  
  auto bestResults = sequentialDupCostsCalculation( results, nucleotides, cfg, algorithmFor( algo, nucleotides, loadStates(), loadMutationCosts() ) );  
  
  if( cfg.printTime ) { cfg.outFile.printTime( Clock.currTime() - startTime ); }
  if( cfg.printResults ) { resFile.printResults( bestResults ); }
  
}


private {
  import std.format;
  
  string RESULTS_HEADER_FORMAT = "%12s%12s%12s\n";
  string RESULT_FORMAT = "%12d%12d%12.8f\n";

  /**
    Prints the results to the standard output in the given order.
  */
  private void printResults( Range )( File output, Range results ) if( isForwardRange!Range ) {
    output.writef( RESULTS_HEADER_FORMAT, "start", "length", "cost" );
    
    foreach( result; results ) {
      output.printResult( result );
    }
  }

  private void printResult( File output, Result result ) {
    output.writef( RESULT_FORMAT, result.start, result.length, result.cost );
  }

  struct FileResultsRange {
    private:
    
      File _input;
    
    public:
    
      this( File input ) { 
        _input = input;
        input.readln(); //Get rid of the header.
      }
    
      auto front() {
        
        size_t start;
        size_t length;
        Cost cost;
        
        auto fieldsRead = _input.readf( RESULT_FORMAT, &start, &length, &cost );
        assert( 3 == fieldsRead, "unable to parse results" );
        
        return result( start, segmentsLength( length ), cost );
        
      }
      
      void popFront() {}
      
      bool empty() { return _input.eof; }  
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
private auto sequentialDupCostsCalculation( Molecule )( ref Results results, Molecule[][] molecules, ref Config cfg, AlgoI!Molecule algorithm ) in {

  assert( 2 <= molecules.length );
  
} body {  
    
  
  //Main loop of the program.
  //For each period length, evaluate de duplication cost of every possible positions.
  size_t seqLength = molecules[ 0 ].length;
  
  auto segmentsLengths = 
    segmentsLengthsFor( 
    
      sequenceLength( seqLength ), 
      minLength( cfg.minLength ), 
      maxLength( cfg.maxLength ), 
      lengthStep( cfg.lengthStep ) 
    
    );
     
  foreach( segmentsLength; segmentsLengths ) {
    
    if( 2 <= cfg.verbosity ) { cfg.outFile.writeln( "Processing segments of length: ", segmentsLength ); }
  
    auto segmentsPairsRange = molecules.segmentPairsForLength( segmentsLength );
    
    foreach( segmentsPairs; segmentsPairsRange ) {
    
      auto cost = algorithm.costFor( segmentsPairs );
      results.add( result( segmentsPairs.leftSegmentStart, segmentsPairs.segmentsLength, cost ) );
      
    }  
  
  }
  
  return results[];
}
