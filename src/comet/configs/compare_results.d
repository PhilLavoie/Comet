module comet.configs.compare_results;

import comet.configs.metaconfig;

alias CompareResultsConfig = typeof( config() );
  

/**
  Factory function for creating the configuration for comparing results.
*/
private auto config() {
  
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

  auto cfg = config();
      
  auto parser = parser();
  
  parser.name = commandName;
  
  parser.add(
    cfg.argFor!( Field.epsilon )(),
    cfg.argFor!( Field.comparedResultsFiles )(),    
  );
    
  bool printConfig = false;
  parser.add( printConfigArg( printConfig ) );
  
  parser.parse!( DropFirst.no )( args );
  
  if( printConfig ) { cfg.print( std.stdio.stdout ); }
  
  return cfg;

}