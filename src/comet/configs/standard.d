/**
  Module defining the standard program usage configuration.
  It is also responsible for initializing said configuration
  based on the commad line arguments.
*/
module comet.configs.standard;

import comet.configs.metaconfig;
import comet.cli.all;

alias StandardConfig = typeof( makeConfig() );
  
/**
  Factory function for creating a configuration.
*/
private auto makeConfig() {
  
  return configFor!(
    Field.sequencesFile,
    Field.verbosity,
    Field.outFile,
    Field.noResults,
    Field.printResults,
    Field.resultsFile,
    Field.printExecutionTime,
    Field.minLength,
    Field.maxLength,
    Field.lengthStep,
    Field.noThreads,
    Field.algo,    
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
    cfg.argFor!( Field.sequencesFile )(),
    cfg.argFor!( Field.verbosity )(),
    cfg.argFor!( Field.outFile )(),
    cfg.argFor!( Field.noResults )(),
    cfg.argFor!( Field.printResults )(),
    cfg.argFor!( Field.resultsFile )(),
    cfg.argFor!( Field.printExecutionTime )(),
    cfg.argFor!( Field.minLength )(),
    cfg.argFor!( Field.maxLength )(),
    cfg.argFor!( Field.lengthStep )(),
    cfg.argFor!( Field.algo )()
  );
  
  bool printConfig = false;
  parser.add( printConfigArg( printConfig ) );
  
  parser.parse!( DropFirst.no )( args );
  
  if( printConfig ) { cfg.print(); }
  
  return cfg;

}