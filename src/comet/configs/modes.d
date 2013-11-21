module comet.configs.modes;

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
private immutable string[ 4 ] modeStrings = [ "generate-references", "compare-results", "run-tests", "compile-measures" ];

/**
  Returns the command line string representation of the mode.
  It makes sure the mode passed is not "standard".
*/  
string toString( Mode mode ) {

  assert( mode != Mode.standard );
  return modeStrings[ mode ];
  
}

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