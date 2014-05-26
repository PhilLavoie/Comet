module comet.scripts.run_tests.program;



/*************************************************************************************
Configuration.
*************************************************************************************/



import comet.configs.metaconfig;

import comet.cli.all: Parser, makeParser, DropFirst;

alias RunTestsConfig = typeof( makeConfig() );


private {  

  /**
    Factory function for creating the configuration for comparing results.
  */
  auto makeConfig() {
    
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
      Field.compileTime
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
      argFor!( Field.epsilon )( cfg ),
      argFor!( Field.verbosity )( cfg ),
      argFor!( Field.sequencesDir )( cfg ),    
      argFor!( Field.referencesDir )( cfg ),
      argFor!( Field.compileTime )( cfg )
    );
      
    bool printConfig = false;
    parser.add( printConfigArg( printConfig ) );
    
    parser.parse!( DropFirst.no )( args );  
    
    if( printConfig ) { cfg.print( std.stdio.stdout ); }    
    
    return cfg;

  }
  
}



/*************************************************************************************
Program.
*************************************************************************************/


import comet.typedefs;
import comet.programcons;

mixin mainRunMixin;
mixin loadConfigMixin;

import comet.scripts.run_tests.callbacks;

import comet.core;

void run( string command, string[] args ) {

  RunTestsConfig cfg;

  if( !loadConfig( cfg, command, args ) ) { return; }
  
  run( cfg );
  
}

private void run( RunTestsConfig cfg ) {

  auto logger = comet.logger.logger( cfg.outFile, cfg.verbosity );

  auto runParamsRange = 
    .runParamsRange( 
      logger, 
      cfg.sequencesFiles, 
      [ Algo.standard ], /* [ Algo.standard, Algo.cache, Algo.patterns, Algo.cachePatterns ],*/
      [ noThreads( 1 ) ] /*, noThreads( 2 ), noThreads( 4 ), noThreads( 8 ), noThreads( 16 ), noThreads( 24 ), noThreads( 32 ) ] */, 
      lengthParameters(
        minLength( cfg.minLength ),
        maxLength( cfg.maxLength ),
        lengthStep( cfg.lengthStep )
      ),
      noResults( cfg.noResults )      
    );
  
  auto storage = makeStorage!(ResultTypeOf!(Nucleotide, VerboseResults.no))( runParamsRange, logger, cfg.referencesDir, cfg.epsilon, false ); //TODO: Don't test for now.
  
  try {
  
    calculateSegmentsPairsCosts(
      runParamsRange,
      storage
    );
    
    if( cfg.compileTime[ 0 ] ) {
    
      printTimeCompilation( cfg.compileTime[ 1 ], storage.timeEntries );
    
    }
    
  } catch( Exception e ) {
  
    logger.logln( 0, e.msg );
  
  }
  
}

void printTimeCompilation( R )( File output, R entries ) if ( isInputRange!R && is( ElementType!R == TimeEntry ) ) {

  string COMPILATION_HEADER_FORMAT = "%40s|%18s|%18s|%18s|%18s|%18s|%18s|%15s(s)";
  //Print header.
  output.writefln( COMPILATION_HEADER_FORMAT, "file", "algorithm", "number of threads", "number of results", "min length", "max length", "length step", "execution time" );
  
  foreach( entry; entries ) {
  
    output.printTimeEntry( entry );
  
  }

}

void printTimeEntry( File output, in ref TimeEntry entry ) {

  import std.path: baseName;
  import comet.utils;

  string ENTRY_WRITE_FORMAT = "%40s|%18s|%18s|%18s|%18s|%18s|%18s|%18s";
  
  output.writefln( 
    ENTRY_WRITE_FORMAT, 
    entry.file.fileName.baseName, 
    entry.algo, 
    entry.noThreads.toString(), 
    entry.noResults.toString(), 
    entry.length.min.toString(),
    entry.length.max.toString(), 
    entry.length.step.toString(), 
    entry.executionTime.executionTimeInSeconds()
  );

}
