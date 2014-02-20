/**
  Module defining the standard program and configuration.
  It is also responsible for initializing said configuration
  based on the commad line arguments.
*/
module comet.program;



/*************************************************************************************
Configuration.
*************************************************************************************/


private {

  import comet.configs.metaconfig;
  import comet.configs.probing;   

  import comet.cli.all: Parser, makeParser, DropFirst;


  alias StandardConfig = typeof( makeConfig() );
  
  /**
    Factory function for creating a configuration.
  */
  auto makeConfig() {
    
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
      Field.phylo,
    )();
    
  }

  /**
    Sets the program name to the given one and parses the argument according to the predefined
    configuration and command line interface. Starts parsing the arguments as they are, does NOT
    skip the first one.
  */
  auto parse( string commandName, string[] args ) {

    auto cfg = makeConfig();
        
    auto parser = makeParser();
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
      cfg.argFor!( Field.algo )(),
      cfg.argFor!( Field.phylo )(),
    );
    
    bool printConfig = false;
    parser.add( printConfigArg( printConfig ) );
    
    parser.parse!( DropFirst.no )( args );
    
    if( printConfig ) { cfg.print(); }
    
    return cfg;

  }
  
}



/*************************************************************************************
Program.
*************************************************************************************/



import compare_results = comet.scripts.compare_results.program;
import run_tests = comet.scripts.run_tests.program;
import hamming = comet.scripts.hamming.program;

import comet.results_io;
import comet.logger;
import comet.typedefs;
import comet.core;
import comet.utils;
import comet.programcons;

import std.stdio;

import std.datetime: Duration;
import std.range: isForwardRange;

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
      
    case Mode.hamming:
    
      hamming.run( command ~ " " ~ mode.toString(), args[ 1 .. $ ] );
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
        
    enforceValidMinLength( cfg.minLength, seqLength / 2 );
    
    //Transfer the sequences into a nucleotides matrix.  
    auto nucleotides = new Nucleotide[][ sequences.length ];
    for( int i = 0; i < nucleotides.length; ++i ) {
    
      nucleotides[ i ] = sequences[ i ].molecules;
      
    }
    
    auto runParamsRange = 
      new class( 
        nucleotides, 
        cfg.algo, 
        loadStates(), 
        loadMutationCosts(), 
        lengthParameters( 
          minLength( cfg.minLength ), 
          maxLength( cfg.maxLength ), 
          lengthStep( cfg.lengthStep ) 
        ),
        noResults( cfg.noResults )
      ) {
    
        private typeof( nucleotides ) _nucleotides;
        private Algo _algo;
        private typeof( loadStates() ) _states;
        private typeof( loadMutationCosts() ) _mutationCosts;
        private bool _empty;
        private LengthParameters _length;
        private NoResults _noResults;
        
        this( 
          typeof( _nucleotides ) nucleotides, 
          typeof( _algo ) algo, 
          typeof( _states ) states, 
          typeof( _mutationCosts ) mutationCosts,
          typeof( _length ) length,
          typeof( _noResults ) noResults
        ) {
        
          _nucleotides = nucleotides;
          _algo = algo;
          _states = states;
          _mutationCosts = mutationCosts;
          _empty = false;
          _length = length;
          _noResults = noResults;
        
        }     
        
        bool empty() { return _empty; }
        void popFront() { _empty = true; }
        auto front() {
        
          return makeRunParameters( 
            _nucleotides,
            _algo,
            _states,
            _mutationCosts,
            noThreads( 1 ),
            _length,
            _noResults
          );      
          
        }
      
      };
    
    auto storage = new class( cfg )  {
  
      private StandardConfig _cfg;
    
      private this( typeof( _cfg ) config ) {
      
        _cfg = config;
        
      }
                
      private void printExecutionTime( Duration time ) { 
      
        if( !_cfg.printExecutionTime ) { return; }
        
        .printExecutionTime( stdout, time );
      
      }
      
      private void printResults( R )( R results ) if( isInputRange!R && is( ElementType!R == Result ) ) {
      
        if( !_cfg.printResults ) { return; }
        
        .printResults( _cfg.resultsFile, results );
      
      }
      
      public void store( RunSummary summary ) {
      
        printResults( summary.results[] );
        printExecutionTime( summary.executionTime );
      
      }
    
    };
       
   calculateSegmentsPairsCosts(
      runParamsRange,      
      storage
    );
    
  } 
  
}