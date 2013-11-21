module comet.configs.compare_results;

import comet.configs.metaconfig;

import std.container;
import std.stdio;
import std.algorithm: map;

import comet.configs.utils;
import comet.cli.all;

alias CompareResultsConfig = typeof( makeConfig() );
  

/**
  Factory function for creating the configuration for comparing results.
*/
private auto makeConfig() {
  
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

  auto cfg = makeConfig();  
  
  debug {
  
    scope( success ) {
      import std.algorithm: count;
      import comet.configs.utils: fileName;
      import std.stdio: File, writeln;
      import std.conv: to;
      
      assert( 2 <= cfg.comparedResultsFiles.count, cfg.comparedResultsFiles.count.to!string );
      
      foreach( File file; cfg.comparedResultsFiles ) {
            
        assert( file.isOpen(), "unopened file " ~ file.fileName() );
      
      }
    }
    
  }
  
  auto parser = parser();
  
  parser.name = commandName;
  
  parser.add(
    argFor!( Field.epsilon )( cfg ),
    argFor!( Field.comparedResultsFiles )( cfg ),    
  );
    
  bool printConfig = false;
  parser.add( printConfigArg( printConfig ) );
  
  parser.parse!( DropFirst.no )( args );  
  
  if( printConfig ) { cfg.print( std.stdio.stdout ); }    
  
  return cfg;

}