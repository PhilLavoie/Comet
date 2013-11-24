module comet.programs.standard;

import comet.cli.all: commandName;

import comet.configs.standard;  //TODO: for some reason, importing this in the function scope creates linker problems....
import comet.configs.probing;   //TODO: ditto.

import compare_results = comet.programs.compare_results;

import comet.results_io;

import comet.logger;

import comet.programs.runs;

import comet.bio.dna;
import comet.containers.tree;
import fasta = comet.bio.fasta;

import std.stdio;
import std.algorithm;
import std.conv;
import std.exception;
import std.container;
import std.datetime;
import std.range: isForwardRange;

/**
  Program entry point.
  Expects the first argument to be the command invocation.
*/
void run( string[] args ) {
      
  run( commandName( args ), args[ 1 .. $ ] );

}

/**
  Uses the command name passes as the one presented to the user.
  Does not expect the command invocation to be in the arguments passed
  (does not drop the first argument).
  
  The sole purpose of this function is to extract the program configuration
  from the command line interface, then delegate to its appropriate overload.
  
  In addition, the standard program also supports the delegation to a specific
  script. Therefore, this function first probes the command line to extract
  the mode/script of operation requested by the user. Then, if one was requested,
  it delegates to the associated program's run function.
*/
package void run( string command, string[] args ) {

  //Standard mode starts with probing.    
  auto mode = probe( args );
  
  /*
    The processing is done in three steps:
      - Identify the mode/script;
      - Use the appropriate command line parser and extract the configuration;
      - Load the appropriate program logic and launch the processing with the given config.
  */
  final switch( mode ) {
  
    case Mode.standard:
      
      auto cfg = parse( command, args );
      run( cfg );
    
      break;
      
    case Mode.generateReferences:   
    case Mode.runTests:
    case Mode.compileMeasures:
      assert( false, "unimplemented yet" ); 
      
    case Mode.compareResults:
    
      compare_results.run( command ~ " " ~ mode.toString(), args[ 1 .. $ ] );
      break;
  
  }

}

private:

auto resultsFileFor( StandardConfig cfg, File file ) {

  return cfg.resultsFile;

}

void run( StandardConfig cfg ) {
  
  Logger logger = .logger( cfg.outFile, cfg.verbosity );
  
  logger.logln( 1, "Processing file: " ~ cfg.sequencesFile.name );

  processFile( cfg.sequencesFile, cfg.resultsFileFor( cfg.sequencesFile ), cfg,  cfg.algos.front );

}

void enforceSequencesLength( Range )( Range sequences, size_t length ) if( isForwardRange!Range ) {
  
  foreach( sequence; sequences ) {
  
    enforce( sequence.molecules.length == length, "Expected sequence: " ~ sequence.id ~ " of length: " ~ sequence.molecules.length.to!string ~ " to be of length: " ~ length.to!string );
  
  }
  
}

/**
  Extract the sequences from the provided file and makes sure they follow the rules of processing:
    - They must be of fasta format;
    - They must be made of dna nucleotides;
    - They must have the same name.  
*/
auto loadSequences( File file ) {

  auto sequences = fasta.parse!( ( char a ) => comet.bio.dna.fromAbbreviation( a ) )( file );
  size_t seqsCount = sequences.length;
  enforce( 2 <= seqsCount, "Expected at least two sequences but read " ~ seqsCount.to!string() );
  
  size_t seqLength = sequences[ 0 ].molecules.length;
  enforceSequencesLength( sequences[], seqLength );
  
  return sequences;
  
}

void processFile( File seqFile, File resFile, StandardConfig cfg, Algo algo ) {

  if( 1 <= cfg.verbosity ) {
    cfg.outFile.writeln( "Processing file " ~ seqFile.name ~ "..." );
  }
  
  
  //Extract sequences from file.
  auto sequences = loadSequences( seqFile );
  size_t seqLength = sequences[ 0 ].molecules.length;
  size_t midPosition = seqLength / 2;
  
  //Make sure the minimum period is within bounds.
  enforce( 
    cfg.minLength <= midPosition,
    "The minimum period: " ~ cfg.minLength.to!string() ~ " is set beyond the mid sequence position: " ~ to!string( midPosition ) ~
    " and is therefore invalid."
  );
  
  //Transfer the sequences into a nucleotides matrix.  
  auto nucleotides = new Nucleotide[][ sequences.length ];
  for( int i = 0; i < nucleotides.length; ++i ) {
  
    nucleotides[ i ] = sequences[ i ].molecules;
    
  }
    
  auto states = loadStates();
  auto mutationCosts = loadMutationCosts();
    
  SysTime startTime;
  if( cfg.printTime ) { startTime = Clock.currTime(); }  
    
  auto sr = .sequencesRun(
    nucleotides,
    minLength( cfg.minLength ),
    maxLength( cfg.maxLength ),
    lengthStep( cfg.lengthStep ),
    noThreads( cfg.noThreads ),
    noResults( cfg.noResults ),    
    algorithmFor( cfg.algos.front, sequencesCount( nucleotides.length ), states, mutationCosts )  
  );
  
  comet.programs.runs.run( sr );
  
  if( cfg.printTime ) { cfg.outFile.printTime( Clock.currTime() - startTime ); }
  if( cfg.printResults ) { resFile.printResults( sr.results[] ); }
  
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