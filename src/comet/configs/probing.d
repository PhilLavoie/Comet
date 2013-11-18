/**
  This module is designed as an entry point for the different configurations
  available for this program.
*/
module comet.configs.probing;

/**
  The program can run in a variety of modes. Its simplest form is the processing
  of a single file. The program can also be used as a tool to compare already generated
  results and to compile measures for a set of files for example.
*/
enum Mode {
  generateReferences = 0,
  compareResults,
  runTests,
  compileMeasures,
  standard
}

//The strings used to identify the modes on the command line. The standard algorithm is the absence of a parameter,
//Therefore there is no strings associated.
immutable string[ 4 ] modeStrings = [ "generate-references", "compare-results", "run-tests", "compile-measures" ];

//The modes mapped by their identifying strings. 
immutable Mode[ string ] modesByStrings;

//Constructs the modes map.
static this() {
  
  foreach( string modeString; __traits( allMembers, Mode ) ) {
  
    enum mode = mixin( "Mode." ~ modeString );    
    
    static if( mode != Mode.standard ) { 
    
      modesByStrings[ modeStrings[ mode ] ] = mode;
      
    }
  
  }
  
}

//Asserts that the map is correctly constructed.
unittest {

  assert( modesByStrings.length == 4 );
  
  auto mode = Mode.generateReferences;
  string modeString = modeStrings[ mode ];  
  assert( modesByStrings[ modeString ] == mode );
  
  mode = Mode.compareResults;
  modeString = modeStrings[ mode ];  
  assert( modesByStrings[ modeString ] == mode );
  
  mode = Mode.runTests;
  modeString = modeStrings[ mode ];  
  assert( modesByStrings[ modeString ] == mode );
  
  mode = Mode.compileMeasures;
  modeString = modeStrings[ mode ];  
  assert( modesByStrings[ modeString ] == mode );
    
}

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
