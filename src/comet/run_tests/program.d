module comet.run_tests.program;



/*************************************************************************************
Configuration.
*************************************************************************************/



import comet.configs.metaconfig;

import comet.cli.all: Parser, parser, DropFirst;

alias RunTestsConfig = typeof( makeConfig() );
  
/**
  Factory function for creating the configuration for comparing results.
*/
private auto makeConfig() {
  
  return configFor!(
    Field.epsilon,
    Field.verbosity,
    Field.outFile,
    Field.minLength,
    Field.maxLength,
    Field.lengthStep,
    Field.noResults,
    Field.sequencesDir,    
    Field.referencesDir,
  )();
  
}

/**
  Sets the program name to the given one and parses the argument according to the predefined
  configuration and command line interface. Starts parsing the arguments as they are, does NOT
  skip the first one.   
*/
auto parse( string commandName, string[] args ) {

  auto cfg = makeConfig();  
    
  auto parser = parser();
  
  parser.name = commandName;
  
  parser.add(
    argFor!( Field.epsilon )( cfg ),
    argFor!( Field.verbosity )( cfg ),
    argFor!( Field.sequencesDir )( cfg ),    
    argFor!( Field.referencesDir )( cfg )
  );
    
  bool printConfig = false;
  parser.add( printConfigArg( printConfig ) );
  
  parser.parse!( DropFirst.no )( args );  
  
  if( printConfig ) { cfg.print( std.stdio.stdout ); }    
  
  return cfg;

}



/*************************************************************************************
Program.
*************************************************************************************/



import comet.programcons;

mixin mainRunMixin;
mixin loadConfigMixin;

import comet.utils;
import comet.core;

import std.range: isInputRange, ElementType;
import std.algorithm: count;
import std.stdio: File;

import comet.compare_results.program: allEquivalents;
import comet.results_io;
import std.exception: enforce;


void run( string command, string[] args ) {

  RunTestsConfig cfg;

  if( !loadConfig( cfg, command, args ) ) { return; }
  
  run( cfg );
  
}

class RunParamsRange {

  import std.container: Array;
  
  private Logger                          _logger;
  
  private Array!File                      _sequencesFiles;
  private int                             _currentFileIndex;
  private Nucleotide[][][]                _sequencesGroups;  
  
  private typeof( loadStates() )          _states;
  private typeof( loadMutationCosts() )   _mutationCosts;
  
  private Array!Algo                      _originalAlgos;
  private typeof( _originalAlgos[] )      _currentAlgos;
  
  private Array!NoThreads                 _originalNoThreads;
  private typeof( _originalNoThreads[] )  _currentNoThreads;
  
  this( FR, AR, NTR )( Logger logger, FR fileRange, AR algoRange, NTR noThreadsRange, size_t minLength ) {
  
    static assert( isInputRange!FR  && is( ElementType!FR == File ) );
    static assert( isInputRange!AR  && is( ElementType!AR == Algo ) );
    static assert( isInputRange!NTR && is( ElementType!NTR == NoThreads ) );
  
    _logger = logger;  
  
    foreach( file; fileRange ) {
    
      _sequencesFiles.insertBack( file );        
    
    }
    
    _sequencesGroups = new Nucleotide[][][ count( _sequencesFiles[] ) ];
    int fileIndex = 0;
    foreach( file; _sequencesFiles ) {
    
      //Extract sequences from file.
      auto sequencesGroup = loadSequences( file );
      size_t seqLength = sequencesGroup[ 0 ].molecules.length;
          
      enforceValidMinLength( minLength, seqLength / 2 );
      
      //Transfer the sequences into a nucleotides matrix.  
      auto nucleotides = new Nucleotide[][ sequencesGroup.length ];
      for( int i = 0; i < nucleotides.length; ++i ) {
      
        nucleotides[ i ] = sequencesGroup[ i ].molecules;
        
      }
      _sequencesGroups[ fileIndex ] = nucleotides;
      ++fileIndex;
    
    }
    
    _states = loadStates();
    _mutationCosts = loadMutationCosts();
    
    foreach( algo; algoRange ) {
    
      _originalAlgos.insertBack( algo );
    
    }
    _currentAlgos = _originalAlgos[];
    
    foreach( noThread; noThreadsRange ) {
    
      _originalNoThreads.insertBack( noThread );
    
    }
    
    _currentNoThreads = _originalNoThreads[];
  
  }
  
  bool empty() { return _currentFileIndex >= _sequencesFiles.length; }
  void popFront() { 
  
    _currentNoThreads.popFront();
  
    if( _currentNoThreads.empty ) {
    
      _currentNoThreads = _originalNoThreads[];
    
      _currentAlgos.popFront();
      
      if( _currentAlgos.empty ) {
      
        _currentAlgos = _originalAlgos[];
        
        ++_currentFileIndex;       
      
      }
    
    }
  
  }
  auto front() {
    
    _logger.logln( 1, "Processing file: ", currentFile().fileName() );
  
    return runParameters( currentSequencesGroup(), currentAlgo(), _states, _mutationCosts, currentNoThreads() );
  
  }
  
  @property File currentFile() { return _sequencesFiles[ _currentFileIndex ]; }
  @property auto currentSequencesGroup() { return _sequencesGroups[ _currentFileIndex ]; }
  @property auto currentAlgo() { return _currentAlgos.front; }
  @property auto currentNoThreads() { return _currentNoThreads.front; }
  
}


private void run( RunTestsConfig cfg ) {

  auto logger = comet.logger.logger( cfg.outFile, cfg.verbosity );

  auto runParamsRange = new RunParamsRange( logger, cfg.sequencesFiles, [ Algo.standard ], [ noThreads( 1 ) ], cfg.minLength );
  
  auto br = makeBatchRun(
    runParamsRange,
    lengthParameters(
      minLength( cfg.minLength ),
      maxLength( cfg.maxLength ),
      lengthStep( cfg.lengthStep )
    ),
    noResults( cfg.noResults ),        
  );
  
  auto storage = new class( logger, cfg, runParamsRange )  {

    private Logger _logger;
    private RunTestsConfig _cfg;
    private RunParamsRange _runParamsRange;
      
    private this( typeof( _logger ) logger, typeof( _cfg ) config, typeof( _runParamsRange ) runParamsRange ) {
    
      _logger = logger;
      _cfg = config;
      _runParamsRange = runParamsRange;
      
    }   
    
    public void store( RunSummary summary ) {
      
      import std.range: roundRobin, chunks;
      
      auto referenceFile = fetch( referenceFileNameFor( _cfg.referencesDir, runParamsRange.currentFile() ) );
      logger.logln( 2, "Comparing results with reference file: ", referenceFile.fileName );
      
      Array!Result empirical;
      foreach( result; summary.results[] ) {
        empirical.insertBack( result );
      }
      Array!Result expected;
      foreach( result; resultsReader( referenceFile ) ) {
        expected.insertBack( result );
      }     
      
      enforce( 
        allEquivalents( [ empirical[], expected[] ], _cfg.epsilon ), 
        "Test ERROR: results for sequences file " ~ runParamsRange.currentFile.fileName() ~ " are not equivalent to reference results file " ~ referenceFile.fileName() ~
        " using epsilon: " ~ _cfg.epsilon.to!string() 
      );
      
      logger.logln( 2, "Results are equivalent to reference with epsilon: ", _cfg.epsilon );
      logger.logln( 3, executionTimeString( summary.executionTime ) );
      
    }
  
  };
  
  try {
  
    br.run( storage ); 
    
  } catch( Exception e ) {
  
    logger.logln( 0, e.msg );
  
  }
  
}

