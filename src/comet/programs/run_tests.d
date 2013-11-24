module comet.programs.run_tests;

import comet.programs.metaprogram;

mixin mainRunMixin;
mixin loadConfigMixin;

import comet.configs.run_tests;

package void run( string command, string[] args ) {

/*
  RunTestsConfig cfg;

  try {
  
    cfg = parse( command, args );
  
  } catch( Exception e ) {
    
    //The exception has been handled by the parser.
    return;
  }
  
  run( cfg );
  
  */

}

/*
private void run( RunTestsConfig cfg ) {






}*/