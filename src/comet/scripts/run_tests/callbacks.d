/**
  This module is designed to hold the callbacks used to parameterize the core
  algorithm of state mutation analysis.
*/
module comet.scripts.run_tests.callbacks;

import comet.logger: Logger;
import std.stdio: File;
import comet.bio.dna: Nucleotide;
import comet.configs.algos: Algo;
import comet.utils;
import std.container: Array;
import comet.typedefs: Cost;
import comet.typedefs: LengthParameters;
import comet.typecons: getter;
import comet.core: RunSummary, makeRunParameters;
import std.range: isInputRange, ElementType;
import std.datetime: Duration;
import std.traits: FieldTypeTuple;

import comet.results;
import comet.results_io;
import comet.scripts.compare_results.program: allEquivalents;

import std.algorithm: count;
import std.exception: enforce;

class RunParamsRange {
 
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
  
  private LengthParameters                _lengthParams;
  mixin getter!_lengthParams;
  
  private NoResults                       _noResults;
  mixin getter!_noResults;
  
  this( FR, AR, NTR )( Logger logger, FR fileRange, AR algoRange, NTR noThreadsRange, LengthParameters length, NoResults noResults ) {
  
    static assert( isInputRange!FR  && is( ElementType!FR == File ) );
    static assert( isInputRange!AR  && is( ElementType!AR == Algo ) );
    static assert( isInputRange!NTR && is( ElementType!NTR == NoThreads ) );
  
    _logger = logger;  
    _lengthParams = length;
    _noResults = noResults;
    
    foreach( file; fileRange ) {
    
      _sequencesFiles.insertBack( file );        
    
    }
    
    _sequencesGroups = new Nucleotide[][][ count( _sequencesFiles[] ) ];
    int fileIndex = 0;
    foreach( file; _sequencesFiles ) {
    
      //Extract sequences from file.
      auto sequencesGroup = loadSequences( file );
      size_t seqLength = sequencesGroup[ 0 ].molecules.length;
          
      enforceValidMinLength( _lengthParams.min, seqLength / 2 );
      
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
    _logger.logln( 2, "Using Configuration: " );
  
    return makeRunParameters( currentSequencesGroup(), currentAlgo(), _states, _mutationCosts, currentNoThreads(), _lengthParams, _noResults );
  
  }
  
  @property File currentFile() { return _sequencesFiles[ _currentFileIndex ]; }
  @property auto currentSequencesGroup() { return _sequencesGroups[ _currentFileIndex ]; }
  @property auto currentAlgo() { return _currentAlgos.front; }
  @property auto currentNoThreads() { return _currentNoThreads.front; }
  
}

auto runParamsRange( T... )( T args ) {

  return new RunParamsRange( args );

}

struct TimeEntry {
  File              file;
  Algo              algo;
  NoThreads         noThreads;
  NoResults         noResults;
  LengthParameters  length;
  Duration          executionTime;
}
auto timeEntry( FieldTypeTuple!TimeEntry args ) {

  return TimeEntry( args );

}

class Storage  {

  private Logger           _logger;
  private string           _referencesDir;
  private Cost             _epsilon;
  private RunParamsRange   _runParamsRange;
  private Array!TimeEntry  _executionTimes;
  private bool             _testAgainstReferences;
    
  private this( typeof( _runParamsRange ) runParamsRange, typeof( _logger ) logger, typeof( _referencesDir ) dir, typeof( _epsilon ) epsilon, bool test = true ) {
  
    _logger = logger;
    _referencesDir = dir;
    _epsilon = epsilon;
    _runParamsRange = runParamsRange;
    _testAgainstReferences = test;
        
  }   
  
  public void store( RunSummary summary ) {
            
    if( _testAgainstReferences ) {
    
      auto referenceFile = fetch( referenceFileNameFor( _referencesDir, _runParamsRange.currentFile() ) );
      _logger.logln( 2, "Comparing results with reference file: ", referenceFile.fileName );
    
      Array!Result empirical;
      foreach( result; summary.results[] ) {
        empirical.insertBack( result );
      }
      Array!Result expected;
      foreach( result; resultsReader( referenceFile ) ) {
        expected.insertBack( result );
      }     
    
      enforce( 
        allEquivalents( [ empirical[], expected[] ], _epsilon ), 
        "Test ERROR: results for sequences file " ~ _runParamsRange.currentFile.fileName() ~ " are not equivalent to reference results file " ~ referenceFile.fileName() ~
        " using epsilon: " ~ _epsilon.to!string() 
      );
      
      _logger.logln( 2, "Results are equivalent to reference with epsilon: ", _epsilon );
      
    }
    
    _logger.logln( 3, executionTimeString( summary.executionTime ) );
    
    _executionTimes.insertBack( 
      timeEntry(         
        _runParamsRange.currentFile,
        _runParamsRange.currentAlgo,
        summary.noThreadsUsed,
        _runParamsRange.noResults,
        _runParamsRange.lengthParams,
        summary.executionTime
      ) 
    );
    
  }
  
  @property public auto timeEntries() { return _executionTimes[]; }

};
auto storage( T... )( T args ) {

  return new Storage( args );

}
