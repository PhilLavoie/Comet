module comet.programs.compare_results;



/*************************************************************************************
Configuration.
*************************************************************************************/



import comet.configs.metaconfig;

import comet.cli.all: Parser, parser, DropFirst;

alias CompareResultsConfig = typeof( makeConfig() );
  

/**
  Factory function for creating the configuration for comparing results.
*/
private auto makeConfig() {
  
  return configFor!(
    Field.epsilon,
    Field.comparedResultsFiles,    
  )();
  
}

/**
  Sets the program name to the given one and parses the argument according to the predefined
  configuration and command line interface. Starts parsing the arguments as they are, does NOT
  skip the first one. 
  
  The compare results configuration is a light one: it holds an optionally
  defined epsilon value and a range of compared files.
*/
auto parse( string commandName, string[] args ) {

  auto cfg = makeConfig();  
  
  auto parser = parser();
  
  parser.name = commandName;
  
  parser.add(
    argFor!( Field.epsilon )( cfg ),
    argFor!( Field.comparedResultsFiles )( cfg ),    
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



import comet.results_io;

import std.algorithm: map, count, filter;
import std.container: Array;
import std.stdio: File, writeln;

import comet.programs.metaprogram;

mixin mainRunMixin;
mixin loadConfigMixin;

/**
  Uses the command name passes as the one presented to the user.
  Does not expect the command invocation to be in the arguments passed
  (does not drop the first argument).
  
  The sole purpose of this function is to extract the program configuration
  from the command line interface, then delegate to its appropriate overload.
*/
package void run( string command, string[] args ) {

  CompareResultsConfig cfg;

  if( !loadConfig( cfg, command, args ) ) { return; }
  
  run( cfg );

}

package void run( CompareResultsConfig cfg ) {

  Array!ResultsReader resultsReaders;
  resultsReaders.reserve( cfg.comparedResultsFiles.count );
  
  foreach( File file; cfg.comparedResultsFiles ) {
  
    resultsReaders.insertBack( resultsReader( file ) );
  
  }
  
  while( 0 == resultsReaders[].filter!( a => a.empty ).count ) {

    Result reference = resultsReaders.front.front;
    
    foreach( ref resultsReader; resultsReaders ) {
    
      if( !reference.isEquivalentTo( resultsReader.front, cfg.epsilon ) ) {
      
        writeln( "Results are not equivalent using epsilon value: ", cfg.epsilon );
        return;
        
      } 
      
      resultsReader.popFront();
    
    }

  }
  
  writeln( "Results are equivalent using epsilon value: ", cfg.epsilon );

}