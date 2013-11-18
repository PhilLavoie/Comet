module comet.programs.standard;


import comet.configs.standard;
import comet.configs.probing;

/**
  Main entry point of the program.
*/
void run( string[] args ) {

  //Extract the command name immediately.
  import cli = comet.cli.all;
  auto command = cli.commandName( args );

  //Standard mode starts with probing.    
  auto mode = probe( args[ 1 .. $ ] );
  
  /*
    The processing is done in three steps:
      - Identify the mode;
      - Use the appropriate command line parser and extract the configuration;
      - Load the appropriate program logic and launch the processing with the given config.
  */
  final switch( mode ) {
  
    case Mode.standard:
          
      auto cfg = parse( command, args[ 1 .. $ ] );
    
      break;
      
    case Mode.generateReferences:
    case Mode.compareResults:
    case Mode.runTests:
    case Mode.compileMeasures:
      assert( false, "unimplemented yet" ); 
  
  }

}

