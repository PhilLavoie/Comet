module comet.configs.standard;

debug( modules ) {

  pragma( msg, "compiling " ~ __MODULE__ );

}

import comet.configs.metaconfig;

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
  )();
  
}

auto parse( string commandName, string[] args ) {

  auto cfg = config();
      
  auto parser = parser();
  parser.name = commandName;
  
  parser.add(
    cfg.argFor!( Field.sequencesFile )()
  );
  
  bool printConfig = false;
  parser.add( printConfigArg( printConfig ) );
  
  parser.parse!( DropFirst.no )( args );
  
  if( printConfig ) { /*cfg.print();*/ }
  
  return cfg;

}