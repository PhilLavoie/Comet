module comet.programs.run_tests;

import comet.programs.metaprogram;

mixin mainRunMixin;
mixin loadConfigMixin;

import comet.configs.run_tests;

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