module comet.configs.standard;

debug( modules ) {

  pragma( msg, "compiling " ~ __MODULE__ );

}

import comet.configs.mixins;
import comet.cli.all;
import comet.configs.algos; //BUG: removing this creates a crash.
import comet.configs.utils; //DITTO

import std.algorithm;

alias StandardConfig = typeof( config() );
  

/**
  Factory function for creating a configuration.
*/
private auto config() {
  
  return configFor!(
    Field.sequencesFile,
    Field.verbosity,
    Field.outFile,
    Field.noResults,
    Field.printResults,
    Field.resultsFile,
    Field.printTime,
    Field.minLength,
    Field.maxLength,
    Field.lengthStep,
    Field.noThreads,
    Field.algos,
    Field.printConfig
  )();
  
}

auto parse( string commandName, string[] args ) {

  auto cfg = config();
    
  auto parser = parser();
  parser.name = commandName;
  
  parser.add(
    cfg.argFor!( Field.sequencesFile )()
  );
  
  parser.parse!( DropFirst.no )( args );
  
  if( cfg.printConfig ) { cfg.print(); }
  
  return cfg;

}