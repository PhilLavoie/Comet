module comet.programs.compare_results;

import comet.cli.all: commandName;
import comet.configs.compare_results;

void run( string[] args ) {

  run( commandName( args ), args[ 1 .. $ ] );

}


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

  //Do nothing for now.

}