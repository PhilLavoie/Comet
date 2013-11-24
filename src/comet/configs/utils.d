module comet.configs.utils;

import std.stdio;

/**
  Small helper function to help print configuration files in a user friendly fashion.
*/
string fileName( File file ) {

  if( file == stdout ) {
  
    return "stdout";
    
  }
  
  if( file == stdin ) {
  
    return "stdin";
    
  }
  
  if( file == stderr ) {
  
    return "stderr";
    
  }
  
  return file.name;
  
}

unittest {

  import std.stdio;
  
  auto name = fileName( stdout );
  assert( name == "stdout" );
  
  name = fileName( stderr );
  assert( name == "stderr" );
  
  name = fileName( stdin );
  assert( name == "stdin" );
  
}