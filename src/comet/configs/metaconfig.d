/**
  Module providing mixin code for creating reusable configuration fields and command line arguments.
  It is responsible to hold and know every static and runtime defaults for every configuration field
  available to the user.
*/
module comet.configs.metaconfig;

public import comet.cli.all;
public import comet.configs.algos;
public import comet.configs.utils;

import std.conv;
import std.file;
import std.algorithm;

version( unittest ) {

  import std.stdio;

}

//"Public" interface of the module.
package {

  /**
    An enumeration of all possible fields available for configuration.
  */
  enum Field {
    sequencesFile,
    sequencesDir,
    resultsFile,
    verbosity,
    outFile,
    printResults,
    noResults,
    printTime,
    minLength,
    maxLength,
    lengthStep,
    noThreads,
    algos,
  }
  
  /**
    Constructs a configuration type based on the given configuration fields, properly initializes it and then
    return it to the caller.
  */
  auto configFor( Fields... )() {
    Config!Fields config;
    config.init();
    
    return config; 
  }
  
  /**
    Factory function for generating a standard command line argument for the given configuration field.
  */
  auto argFor( Field field, C )( ref C cfg ) {

    return cfg.argForImpl!field;

  }
  
  /**
    Because we don't want to bloat the configuration with a field the rest of the program doesn't want,
    but because we want to be able to provide a standard command line argument for printing the configuration
    on screen, this factory function has been created. It creates a command line argument that will set
    the reference boolean value to true if the user request the printing of the configuration.
  */
  auto printConfigArg( ref bool printConfig ) in {
  
    assert( !printConfig );
  
  } body {
  
    return toggle( 
      "--print-config", 
      "Prints the used configuration before starting the process if the flag is present.",
      printConfig,      
    );

  }     
  
}

unittest {
  
  alias fields = std.traits.EnumMembers!Field;
  
  //Construct a configuration with every field available.
  auto cfg = configFor!( fields )();
  
  static assert( isConfig!cfg );
  static assert( __traits( compiles, cfg.get!( Field.sequencesFile )() ) );
  static assert( __traits( compiles, cfg.get!( Field.sequencesDir )() ) );
  
  //Make sure the fields are in the configuration.
  foreach( field; fields ) {
    
    static assert( hasField!( cfg, field ) );
    //Make sure the arguments factories compile.
    static assert( __traits( compiles, cfg.get!( field )() ), fieldString!field );
    static assert( __traits( compiles, cfg.argFor!( field )() ), fieldString!field );
    
  }
  
  //Check the runtime defaults.
  assert( cfg.resultsFile == stdout );
  assert( cfg.outFile == stdout );
  assert( cfg.algos.count == 1 && cfg.algos.front == Algo.standard );   

}


//Fields related stuff.
private {

  /**
    Templated structs that will hold all the configuration fields.
  */
  struct Config( Fields... ) if( 1 <= Fields.length ) {
  
    mixin fields!( Fields );      
    mixin initAllFields;
  
  }  
  
  /**
    Returns the field string as to!string() would.
  */
  template fieldString( Field f ) {
  
    enum fieldString = f.to!string();
    
  }
  
  unittest {
  
    static assert( fieldString!( Field.sequencesFile ) == "sequencesFile", fieldString!( Field.sequencesFile ) );  
    static assert( memberName!( Field.sequencesFile ) == "_sequencesFile" );
    
    static assert( fieldString!( Field.sequencesDir ) == "sequencesDir" );  
    static assert( memberName!( Field.sequencesDir ) == "_sequencesFiles" );
    
  
  }
   
  /**
    Returns the member name as generated inside the configuration struct for the
    given field.
  */
  template memberName( Field f ) {
  
    static if( f == Field.sequencesDir ) {
    
      enum memberName = "_sequencesFiles";
    
    } else {
    
      enum memberName = "_" ~ fieldString!f;
      
    }
  
  }

  /**
    Instantiate the given fields.
  */
  mixin template fields( Fields... ) if( 1 <= Fields.length ) {
  
    mixin field!( Fields[ 0 ] );
    
    static if( 2 <= Fields.length ) {
    
      mixin fields!( Fields[ 1 .. $ ] );
      
    }
  
  }
  ///Ditto.  
  mixin template field( Field f ) {
  
    mixin( "mixin " ~ fieldString!f ~ "Field;" );
  
  }
    

  /*********************************************************************************************************
    Field declaration mixins.
  *********************************************************************************************************/

  mixin template sequencesFileField() {
  
    private std.stdio.File _sequencesFile;  
    mixin getter!_sequencesFile;
 
  }

  mixin template sequencesDirField() {
  
    private std.container.Array!( std.stdio.File ) _sequencesFiles;

    //Returns a range over the sequences files.
    public @property auto sequencesFiles() { return _sequencesFiles[]; }
  
  }
  
  mixin template resultsFileField() {
  
    private std.stdio.File _resultsFile;
    mixin getter!_resultsFile;
    
    mixin defaultSetter!( identifier!_resultsFile, identifier!_resultsFile ~ " = std.stdio.stdout;" );  
  
  }
  
  mixin template verbosityField() {
  
    private ubyte _verbosity = 0;  
    mixin getter!_verbosity;
  
  }
  
  mixin template outFileField() {
    
    private std.stdio.File _outFile;
    mixin getter!_outFile;
    
    mixin defaultSetter!( identifier!_outFile, identifier!_outFile ~ " = std.stdio.stdout;" );
    
  }
  
  mixin template printResultsField() {
  
    private bool _printResults = true;
    mixin getter!_printResults;  
  
  }
  
  mixin template noResultsField() {
  
    size_t _noResults = 1000;    
    mixin getter!_noResults;
  
  }
  
  mixin template printTimeField() {
  
    bool _printTime = true;
    mixin getter!_printTime;  
  
  }
  
  mixin template minLengthField() {
  
    size_t _minLength = 3;
    mixin getter!_minLength;    
  
  }
  
  mixin template maxLengthField() {
  
    size_t _maxLength = size_t.max;
    mixin getter!_maxLength;
  
  }
  
  mixin template lengthStepField() {
  
    size_t _lengthStep = 3;
    mixin getter!_lengthStep;
  
  }
  
  mixin template noThreadsField() {
  
    size_t _noThreads = 1;
    mixin getter!_noThreads;  
  
  }
  
  mixin template algosField() {
  
    private std.container.Array!( comet.configs.algos.Algo ) _algos;  
    public @property auto algos() { return _algos[]; }
    
    mixin defaultSetter!( identifier!_algos, identifier!_algos ~ ".insertBack( comet.configs.algos.Algo.standard );" );  
  
  }
    
  /*********************************************************************************************************
    Launch initialization.
  *********************************************************************************************************/
  
  mixin template initAllFields() {
  
    public void init() {

      alias T = typeof( this );
    
      foreach( member; __traits( allMembers, T ) ) {        
        
        //Runtime defaults for variables such as files.
        mixin hasDefaultSetter!member;
        
        static if( hasDefaultSetter ) {
                
          mixin( defaultSetterFor!member ~ ";" );
        
        }
      
      }
    
    }
    
  }
  
  /*********************************************************************************************************
    Utilities.
  *********************************************************************************************************/
  
  /**
    Returns the string name of the identifier as provided by __traits( identifier, var ).
  */
  template identifier( alias var ) {
    enum identifier = __traits( identifier, var );  
  }
  
  /**
    Generates a getter function for the given variable. The variable must hold the symbol and not be a string
    (a way to ensure the variable exists).
    
    It enforces that the given symbol name starts with "_".
  */
  mixin template getter( alias var ) {
    
    static assert( identifier!var[ 0 ] == '_' );
    
    mixin( "public @property auto " ~ ( identifier!( var ) )[ 1 .. $ ] ~ "() { return " ~ identifier!var ~ "; } " );
    
  }
  
  /**
    Generate a default runtime value setter for the given symbol mixes in the given statement.
    
    It enforces that the given symbol name starts with "_".
  */
  mixin template defaultSetter( string var, string statement ) {
  
    debug( fields ) {
    
      pragma( msg, "generating default runtime setter for " ~ var );
    
    }
  
    mixin( "private void setDefault" ~ var ~ "() { mixin( \"" ~ statement ~ "\" ); }" );    
  
  }
  
  /**
    Returns true if the member has a default runtime initializer, false otherwise.
  */
  mixin template hasDefaultSetter( string member ) {
  
    enum hasDefaultSetter = __traits( compiles, mixin( defaultSetterFor!member ) );
  
  }
  
  /**
    Returns the default setter call string for the given member.
  */
  template defaultSetterFor( string member ) {
    
    enum defaultSetterFor = "setDefault" ~ member ~ "()";
  
  }
  
  unittest {
  
    int someVar = 0;
    enum id = identifier!someVar;
    
    //mixin defaultSetter!( id, "5" ); compiles????
    mixin defaultSetter!( id, id ~ " = 5;" );
    mixin hasDefaultSetter!id;
    
    static assert( hasDefaultSetter, defaultSetterFor!id );
    
    mixin( defaultSetterFor!id ~ ";" );
    
    assert( someVar == 5 );
  
  }
  
  /**
    Returns true if the given expression/type is an instance of a configuration
    generated by this module.
  */
  template isConfig( alias config ) if( !is( config ) ) {
  
    enum isConfig = isConfig!( typeof( config ) );
 
  }
  ///DITTO.
  template isConfig( alias T ) if( is( T ) ) {
  
    enum isConfig = std.traits.isInstanceOf!( Config, T );
  
  }
  
  /**
    Returns true if the given configuration holds the field.
  */
  template hasField( alias config, Field f ) if( !is( config ) ) {
  
    enum hasField = hasField!( typeof( config ), f );
  
  }
  ///DITTO.
  template hasField( alias T, Field f ) if( is( T ) ) {
  
    enum hasField = __traits( hasMember, T, memberName!f );
  
  }
  
  /**
    This function extracts a field by reference from a configuration to be passed to an
    argument factory.
  */
  auto ref get( Field field, C )( ref C cfg ) if( isConfig!C && hasField!( C, field ) ) {
  
    return __traits( getMember, cfg, memberName!( field ) );
  
  }

}


//Arguments related stuff.
private {

  auto argForImpl( Field field, C )( ref C cfg ) if( field == Field.sequencesFile ) {

    return indexedRight( 
      0u,
      "sequencesFile", 
      "This argument is the file holding the sequences to process.", 
      commonParser( fileConverter( "r" ), cfg.get!field()  ),
      mandatory
    );

  }

  auto argForImpl( Field field, C )( ref C cfg ) if( field == Field.sequencesDir ) {

    return indexedRight( 
      0u,
      "sequences directory", 
      "This argument indicates the directory where the sequences files are located. All files are used, so make sure only sequences files are there.", 
      commonParser(
        //Converter, do nothing.
        ( string[] args ) => args[ 0 ],
        //Eagerly read the directory for sequences files.
        ( string dir ) {         
          foreach( file; dirEntries( dir, SpanMode.shallow ).map!( a => std.stdio.File( a, "r" ) ) ) {
            cfg.get!field().insertBack( file );
          }
        } 
      ),
      mandatory
    );

  }
  
  auto argForImpl( Field field, C )( ref C cfg ) if( field == Field.resultsFile ) {

    return file( 
      "--rf",
      "Results file. This is where the program prints the results. Default is stdout.",
      cfg.get!field(), 
      "w"
    );  

  }
  
  auto argForImpl( Field field, C )( ref C cfg ) if( field == Field.verbosity ) {

    return value( 
      "-v", 
      "Verbosity level. Default is " ~ to!string( cfg.get!field() ) ~ ".", 
      cfg.get!field()        
    );

  }
  
  auto argForImpl( Field field, C )( ref C cfg ) if( field == Field.outFile ) {

    return file( 
      "--of", 
      "Output file. This is where the program emits statements. Default is stdout.", 
      cfg.get!field(), 
      "w" 
    );

  }
  
  auto argForImpl( Field field, C )( ref C cfg ) if( field == Field.printResults ) {

    return toggle( "--no-res", "Prevents the results from being printed.", cfg.get!field() );

  }
  
  auto argForImpl( Field field, C )( ref C cfg ) if( field == Field.noResults ) {

    return value(  
      "--nr ",  
      "Number of results to keep in memory. Default is  " ~ to!string( cfg.get!field() ) ~  ". ",
      cfg.get!field()
    );

  }
  
  auto argForImpl( Field field, C )( ref C cfg ) if( field == Field.printTime ) {

    return toggle(
      "--no-time ",
      "Removes the execution time from the results. ",
      cfg.get!field() 
    );

  }
  
  auto argForImpl( Field field, C )( ref C cfg ) if( field == Field.minLength ) {

    return value(  
      "--min ",  
      "Minimum period length. Default is  " ~ std.conv.to!string( cfg.get!field() ) ~  ". ", 
      cfg.get!field() 
    );

  }
      
  auto argForImpl( Field field, C )( ref C cfg ) if( field == Field.maxLength ) {

    return value( 
      "--max",
      "Maximum period length. Default is the biggest value held by a word. The mid sequence position is used if it is lower than this value.",
      cfg.get!field() 
    );

  }
  
  auto argForImpl( Field field, C )( ref C cfg ) if( field == Field.lengthStep ) {

    return setter( 
      "--single-step",
      "Sets the segment pair length step to be 1. The default is " ~ std.conv.to!string( cfg.get!field() ) ~ " instead of 3.",
      cfg.get!field(),
      1u
    );

  }   

  auto argForImpl( Field field, C )( ref C cfg ) if( field == Field.noThreads ) {

    assert( false, "unimplemented" );

  }     
  
  auto argForImpl( Field field, C )( ref C cfg ) if( field == Field.algos ) {

    return flagged( 
      "--algo", 
      "Sets the segment pair cost calculation algorithm. Possible values are \"standard\", \"cache\", \"patterns\" and \"cache-patterns\".", 
      commonParser( mappedConverter( comet.configs.algos.algosByStrings ), ( comet.configs.algos.Algo algo ) { cfg.get!field().insertBack( algo ); } ),
      optional
    );

  }      
  
}