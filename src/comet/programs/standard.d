/**
  Module defining the standard program and configuration.
  It is also responsible for initializing said configuration
  based on the commad line arguments.
*/
module comet.programs.standard;



/*************************************************************************************
Configuration.
*************************************************************************************/



import comet.configs.metaconfig;
import comet.configs.probing;   

import comet.cli.all: Parser, parser, DropFirst;


private alias StandardConfig = typeof( makeConfig() );
  
/**
  Factory function for creating a configuration.
*/
private auto makeConfig() {
  
  return configFor!(
    Field.sequencesFile,
    Field.verbosity,
    Field.outFile,
    Field.noResults,
    Field.printResults,
    Field.resultsFile,
    Field.printExecutionTime,
    Field.minLength,
    Field.maxLength,
    Field.lengthStep,
    Field.noThreads,
    Field.algo,    
  )();
  
}

/**
  Sets the program name to the given one and parses the argument according to the predefined
  configuration and command line interface. Starts parsing the arguments as they are, does NOT
  skip the first one.
*/
private auto parse( string commandName, string[] args ) {

  auto cfg = makeConfig();
      
  auto parser = parser();
  parser.name = commandName;
  
  parser.add(
    cfg.argFor!( Field.sequencesFile )(),
    cfg.argFor!( Field.verbosity )(),
    cfg.argFor!( Field.noResults )(),
    cfg.argFor!( Field.printResults )(),
    cfg.argFor!( Field.resultsFile )(),
    cfg.argFor!( Field.printExecutionTime )(),
    cfg.argFor!( Field.minLength )(),
    cfg.argFor!( Field.maxLength )(),
    cfg.argFor!( Field.lengthStep )(),
    cfg.argFor!( Field.algo )()
  );
  
  bool printConfig = false;
  parser.add( printConfigArg( printConfig ) );
  
  parser.parse!( DropFirst.no )( args );
  
  if( printConfig ) { cfg.print(); }
  
  return cfg;

}



/*************************************************************************************
Program.
*************************************************************************************/



import compare_results = comet.programs.compare_results;
import run_tests = comet.programs.run_tests;

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

import comet.programs.metaprogram;

mixin mainRunMixin;
mixin loadConfigMixin;


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
      
      StandardConfig cfg;
      
      if( !loadConfig( cfg, command, args ) ) { return; }
      
      run( cfg );
    
      break;
      
    case Mode.generateReferences:   
    case Mode.compileMeasures:
      assert( false, "unimplemented yet" ); 
    
    case Mode.runTests:
    
      run_tests.run( command ~ " " ~ mode.toString(), args[ 1 .. $ ] );
      break;
    
    case Mode.compareResults:
    
      compare_results.run( command ~ " " ~ mode.toString(), args[ 1 .. $ ] );
      break;
  
  }

}

private {

  void run( StandardConfig cfg ) {
    
    Logger logger = .logger( cfg.outFile, cfg.verbosity );
    
    logger.logln( 1, "Processing file: " ~ cfg.sequencesFile.name );
    
    //Extract sequences from file.
    auto sequences = loadSequences( cfg.sequencesFile );
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
       
    auto algos = new class( [ cfg.algo ], sequencesCount( nucleotides.length ) ) {
      
      private typeof( StandardConfig.algo )[] _algos;
      private SequencesCount _sequencesCount;
      private typeof( loadStates() ) _states;
      private typeof( loadMutationCosts() ) _mutationCosts;
      
      private this( typeof( _algos ) algos, typeof( _sequencesCount ) sequencesCount ) {
      
        _algos = algos;
        _sequencesCount = sequencesCount;
        _states = loadStates();
        _mutationCosts = loadMutationCosts();
      
      }
      
      auto front() { return algorithmFor( _algos[ 0 ], _sequencesCount, _states, _mutationCosts ); }
      void popFront() { _algos = _algos[ 1 .. $ ]; }
      bool empty() { return !_algos.length; }   
    
    };
          
    auto br = makeBatchRun(
      minLength( cfg.minLength ),
      maxLength( cfg.maxLength ),
      lengthStep( cfg.lengthStep ),
      sequenceLength( seqLength ),
      noResults( cfg.noResults ),    
      [ nucleotides ],      
      algos,
      [ noThreads( cfg.noThreads ) ]
    );
    
    auto io = new class( cfg, logger )  {
  
      private StandardConfig _cfg;
      private Logger _logger;
    
      private this( typeof( _cfg ) config, typeof( _logger ) logger ) {
        _cfg = config;
      }
    
      public @property logger() { return _logger; }
      
      public void printExecutionTime( Duration time ) { 
      
        if( !_cfg.printExecutionTime ) { return; }
        
        .printExecutionTime( stdout, time );
      
      }
      
      public void printResults( R )( R results ) if( isInputRange!R && is( ElementType!R == Result ) ) {
      
        if( !_cfg.printResults ) { return; }
        
        .printResults( _cfg.resultsFile, results );
      
      }
    
    };
    
    br.run( io ); 

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

  /**
    Prints the execution time value to the given output.
  */
  private void printExecutionTime( File output, Duration time ) {
    output.writeln( "execution time in seconds: ", time.total!"seconds", ".", time.fracSec.msecs );
  }
  
}