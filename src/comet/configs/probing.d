/**
  This module is designed as an entry point for the different configurations
  available for this program.
*/
module comet.configs.probing;

public import comet.configs.modes;

/**
  This function is used to get the mode out of the given token.
  If the slice is empty than standard is returned.
  Only the first argument is used and if it correctly maps
  to a mode than that mode is returned. The default mode is returned
  otherwise (standard).
*/
Mode probe( string[] tokens ) {

  if( !tokens.length ) { return Mode.standard; }
  
  return probe( tokens[ 0 ] );

}
///Ditto.
Mode probe( string token ) {

  return modesByStrings.get( token, Mode.standard ); 

}

unittest {

  assert( probe( cast( string[] )[] ) == Mode.standard );
  assert( probe( [ "toto" ] ) == Mode.standard );
  
  auto mode = Mode.generateReferences;
  auto tokens = [ modeStrings[ mode ], "noise" ];  
  assert( probe( tokens ) == mode );
  
  mode = Mode.compareResults;
  tokens = [ modeStrings[ mode ], "noise" ];  
  assert( probe( tokens ) == mode );
  
  mode = Mode.runTests;
  tokens = [ modeStrings[ mode ], "noise" ];  
  assert( probe( tokens ) == mode );
  
  mode = Mode.compileMeasures;
  tokens = [ modeStrings[ mode ], "noise" ];  
  assert( probe( tokens ) == mode );

}
