module comet.programs.run_tests;



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
    Field.sequencesDir,    
    Field.referencesDir,
    Field.testsResultsDir
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
    argFor!( Field.referencesDir )( cfg ),    
    argFor!( Field.testsResultsDir )( cfg )
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



import comet.programs.metaprogram;

mixin mainRunMixin;
mixin loadConfigMixin;

import std.range: isInputRange, ElementType;
import std.stdio: File;

package void run( string command, string[] args ) {

  RunTestsConfig cfg;

  try {
  
    cfg = parse( command, args );
  
  } catch( Exception e ) {
    
    //The exception has been handled by the parser.
    return;
  }
  
  run( cfg );
  
}

private void run( RunTestsConfig cfg ) {

  //Generate all results first.
  //processFile( File input, makeFile( resultsFileNameFor() ), config );
  
  //Compare every result.




}

//Take the states and the mutation costs provider?
private void runFiles( R )( R sequencesFiles ) if( isInputRange!R && is( ElementType!R == File ) ) {

  foreach( file; sequencesFiles ) {
  
    //Load the sequences.
    
    //Launch a sequences runs.
  
  }

}

private void runSequences( R )( R sequences ) if( isInputRange!R ) {

  foreach( sequence; sequences ) {
  
    //Get the time.
  
    //Run the sequence.
    
    //Print results && time.
  
  }


}