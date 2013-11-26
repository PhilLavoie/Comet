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
import comet.results;
import std.range: frontTransversal, zip;
import std.algorithm: find;


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

  if( allEquivalents( cfg.comparedResultsFiles, cfg.epsilon ) ) {
  
    writeln( "all results are equivalents using epsilon: ", cfg.epsilon );
  
  } else {
  
    writeln( "results are not equivalents using epsilon: ", cfg.epsilon );
  
  }

}

template isResultsRange( R ) {

  enum isResultsRange = isInputRange!R && is( ElementType!R == Result );

}

bool allEquivalents( R )( R results, Cost epsilon ) if( isResultsRange!R ) {

  Result reference = results.front;

  return results.find!( a => !a.isEquivalentTo( reference, epsilon ) ).empty;

}


template isResultsRangeOfRanges( RoR ) {

  enum isResultsRangeOfRanges = isForwardRange!RoR && isResultsRange!( ElementType!RoR );

}

bool allEquivalents( RoR )( RoR ror, Cost epsilon  ) if ( isResultsRangeOfRanges!RoR ) {

  //While no results range is empty.
  while( 0 == ror.filter!( a => a.empty ).count ) {

    //Check if all results are equivalent.
    if( !allEquivalents( ror.frontTransversal, epsilon ) ) { 
    
      return false;       
      
    }        
    
    //Pick up every range by reference to be able to move them.
    foreach( ref resultsRange; ror ) {
    
      resultsRange.popFront();
    
    }

  }
  
  return true;

}

template isFileRange( R ) {

  enum isFileRange = isInputRange!R && is( ElementType!R == File );

}

bool allEquivalents( FR )( FR fileRange, Cost epsilon ) if( isFileRange!FR ) {

  Array!ResultsReader resultsReaders;
    
  foreach( File file; fileRange ) {
  
    resultsReaders.insertBack( resultsReader( file ) );
  
  }
  
  return allEquivalents( resultsReaders[], epsilon );

}