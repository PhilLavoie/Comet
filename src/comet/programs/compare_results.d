module comet.programs.compare_results;

import comet.cli.all: commandName;
import comet.configs.compare_results;

import comet.results_io;

import std.algorithm: map, count, filter;
import std.container: Array;
import std.stdio: File, writeln;

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
*/
package void run( string command, string[] args ) {

  CompareResultsConfig cfg;

  try {
  
    cfg = parse( command, args );
  
  } catch( Exception e ) {
    
    //The exception has been handled by the parser.
    return;
  }
  
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