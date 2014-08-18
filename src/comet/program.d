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

  import comet.cli: Parser, makeParser, DropFirst;


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
      Field.verboseResultsFile
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
      cfg.argFor!(Field.sequencesFile)(),
      cfg.argFor!(Field.verbosity)(),
      cfg.argFor!(Field.noResults)(),
      cfg.argFor!(Field.printResults)(),
      cfg.argFor!(Field.resultsFile)(),
      cfg.argFor!(Field.printExecutionTime)(),
      cfg.argFor!(Field.minLength)(),
      cfg.argFor!(Field.maxLength)(),
      cfg.argFor!(Field.lengthStep)(),
      //cfg.argFor!(Field.algo)(),
      cfg.argFor!(Field.phylo)(),
      cfg.argFor!(Field.verboseResultsFile)(),
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

import comet.results;
import comet.results_io;

import comet.logger;
import comet.typedefs;
import comet.core;
import comet.loader;
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

  //Standard mode starts with probing the command line
  //to see which program to defer to, if any.
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
    
    //Initiate the program logger with required verbosity.
    Logger logger = .logger( cfg.outFile, cfg.verbosity );
    
    logger.logln( 1, "Processing file: " ~ cfg.sequencesFile.name );
    
    //Extract sequences from file.
    auto sequences = loadSequences!( MultipleSequences.yes, ExtendedAbbreviations.yes )( cfg.sequencesFile );
    size_t seqLength = sequences[ 0 ].molecules.length;
    
    //Make sure the minimum length is not above the maximum allowed.
    enforceValidMinLength( cfg.minLength, seqLength / 2 );
    
    //Transfer the sequences into a matrix for uniform access.
    alias Data = typeof( ( sequences[ 0 ] ).molecules );    
    auto nucleotides = new Data[ sequences.length ];
    
    for( int i = 0; i < nucleotides.length; ++i ) 
    {    
      nucleotides[ i ] = sequences[ i ].molecules;      
    }
    
    import std.traits: Unqual;
    
    //Have to remove the const qualifier otherwise have to assign differently.
    //TODO: find another way.
    alias PhyloType = Unqual!(typeof(defaultPhylogeny(nucleotides[])));
    
    PhyloType phylo;
    //Extract the phylogeny.
    if(cfg.phylo() == File.init)
    {
      phylo = cast(PhyloType)defaultPhylogeny(nucleotides[]);
    }
    else
    {
      phylo = cast(PhyloType)loadPhylogeny(cfg.phylo(), nucleotides[]);
    }
    
    //A parameters range that just work on one file.
    auto runParamsRange = 
      new class( 
        phylo, 
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
    
        private typeof(phylo) _phylo;
        private Algo _algo;
        private typeof( loadStates() ) _states;
        private typeof( loadMutationCosts() ) _mutationCosts;
        private bool _empty;
        private LengthParameters _length;
        private NoResults _noResults;
        
        this( 
          typeof( _phylo ) phylo, 
          typeof( _algo ) algo, 
          typeof( _states ) states, 
          typeof( _mutationCosts ) mutationCosts,
          typeof( _length ) length,
          typeof( _noResults ) noResults
        ) {
        
          _phylo = phylo;
          _algo = algo;
          _states = states;
          _mutationCosts = mutationCosts;
          _empty = false;
          _length = length;
          _noResults = noResults;
        
        }     
        
        bool empty() {return _empty;}
        void popFront() {_empty = true;}
        auto front() 
        {        
          return makeRunParameters( 
            _phylo,
            _algo,
            _states,
            _mutationCosts,
            noThreads( 1 ),
            _length,
            _noResults
          );                
        }      
      };
    
    if(cfg.verboseResultsFile.isOpen())
    {  
      alias ResultType = ResultTypeOf!(Nucleotide, VerboseResults.yes);
      //Basic storage that prints results and execution time to the request of the user.
      auto storage = new class( cfg )  
      {
    
        private StandardConfig _cfg;
      
        private this( typeof( _cfg ) config ) {
        
          _cfg = config;
          
        }
                  
        private void printExecutionTime( Duration time ) { 
        
          if( !_cfg.printExecutionTime ) { return; }
          
          .printExecutionTime( stdout, time );
        
        }
        
        private void printResults( R )( R results ) if( isInputRange!R && isResult!(ElementType!R) ) {
        
          if( !_cfg.printResults ) { return; }
          
          .printResults( _cfg.resultsFile, results );
        
        }
        
        private void printVerboseResults(Range)(Range results) if(isInputRange!Range && isResult!(ElementType!Range))
        {
          if(!_cfg.verboseResultsFile().isOpen()) {return;}
          .printVerboseResults(_cfg.verboseResultsFile, results);
        }
        
        public void store(RunSummary!ResultType summary) 
        {        
          printResults(summary.results[]);
          printVerboseResults(summary.results[]);
          printExecutionTime(summary.executionTime);        
        }      
      };
    
      //Start the algorithm with the given configuration.
      calculateSegmentsPairsCosts!(VerboseResults.yes)(
        runParamsRange,      
        storage
      );
    }
    else
    {
      alias ResultType = ResultTypeOf!(Nucleotide, VerboseResults.no);
      //Basic storage that prints results and execution time to the request of the user.
      auto storage = new class( cfg )  {
    
        private StandardConfig _cfg;
      
        private this( typeof( _cfg ) config ) {
        
          _cfg = config;
          
        }
                  
        private void printExecutionTime( Duration time ) { 
        
          if( !_cfg.printExecutionTime ) { return; }
          
          .printExecutionTime( stdout, time );
        
        }
        
        private void printResults( R )( R results ) if( isInputRange!R && isResult!(ElementType!R) ) {
        
          if( !_cfg.printResults ) { return; }
          
          .printResults( _cfg.resultsFile, results );
        
        }
        
        public void store( RunSummary!ResultType summary ) {
        
          printResults( summary.results[] );
          printExecutionTime( summary.executionTime );
        
        }
      
      };
   
     //Start the algorithm with the given configuration.
     calculateSegmentsPairsCosts!(VerboseResults.no)(
        runParamsRange,      
        storage
      );
    }    
  }   
}