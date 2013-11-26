/**
  This module provides facilities for building standardized program artefacts.  
*/
module comet.programcons;

public import comet.cli.utils: commandName;

/**
  This mixin is only to be used by the program's entry point. It generates a main
  that calls mainRun with the arguments received, therefore, such a function
  must be visible in the global scope.
*/
mixin template mainMixin() {

  void main( string[] args ) {
  
    mainRun( args );
  
  }

}

/**
  This mixin generates the standard entry point for programs.
  The function's signature is:
  
  void mainRun( string[] args );
  
  It will delagate to a function whose signature is:
  
  void run( string commandName, string[] args );
  
  It is expected to be visible as is in the instantiation scope.
  This function must not drop the first argument as this is done
  by the generate function.
*/
mixin template mainRunMixin() {

  /**
    Program entry point.
    Expects the first argument to be the command invocation.    
  */
  void mainRun( string[] args ) {
  
    run( commandName( args[ 0 ] ), args[ 1 .. $ ] );
  
  }


}

/**
  Generates a standard function for loading a configuration
  from the command line. 
  
  The function's signature is:
  
  bool loadConfig( ref Config cfg, string commandName, string[] arguments );
  
  Note that the function expects a function whose signature is:
  
  Config parse( string commandName, string[] arguments );
  
  To be visible in the instantiation scope.

*/
mixin template loadConfigMixin() {

  /**
    Loads the configuration from the command line.  
    Returns true if everything is fine, false otherwise.
  */
  bool loadConfig( Config )( ref Config cfg, string commandName, string[] args ) {

    try {
    
      cfg = parse( commandName, args );
    
    } catch( Exception e ) {
      
      //The exception has been handled by the parser.
      return false;

    }
    
    return true;
  
  }

}