/**
  Module providing mixin code for creating reusable configuration fields and command line arguments.
*/
module comet.configs.mixins;

import comet.cli.all;

/**
  Dummy template created to determine if a template argument can be used as a compile time string.
*/
package {

  /*********************************************************************************************************
    Argument and variable mixin sections, to be used directly by the user.
  *********************************************************************************************************/
  
  //TODO: implement runtime defaults for files and algorithms.
  
  /**
    This mixin template generates a file variable name sequencesFile that
    will hold the file provided by the user on the command line. This
    argument is mandatory and it is meant to be the first on the right
    side of the flagged arguments (options).
  */
  mixin template sequencesFileMixin() {
        
    private std.stdio.File _sequencesFile;  
    mixin getter!_sequencesFile;
        
    mixin argumentMixin!(
      _sequencesFile,
      "indexedRight( 
        0u,
        \"sequencesFile\", 
        \"This argument is the file holding the sequences to process.\", 
        commonParser( fileConverter( \"r\" ), _sequencesFile ),
        mandatory
      )"    
    ); 
    
  }

  /**
    This mixin generates an argument for the command line that expects a sequences files DIRECTORY
    as the first argument on the right of the options. However, for convenience purposes,
    it generates a getter that returns a range over the sequences files located in the directory.
    
    The getter is named "sequencesFiles".
  */
  mixin template sequencesDirMixin() {
    
    private std.container.Array!( std.stdio.File ) _sequencesFiles;

    //Returns a range over the sequences files.
    public @property auto sequencesFiles() { return _sequencesFiles[]; }
    
    mixin argumentMixin!(
      _sequencesFile,
      "indexedRight( 
        0,
        \"sequences directory\", 
        \"This argument indicates the directory where the sequences files are located. All files are used, so make sure only sequences files are there.\", 
        commonParser(
          ( string[] args ) => args[ 0 ],
          ( string dir ) {         
            foreach( file; dirEntries( dir, SpanMode.shallow ).map!( a => std.stdio.File( a, \"r\" ) ) ) {
              _sequencesFiles.insertBack( file );
            }
          } 
        ),
        mandatory
      )"
    ); 
    
  }

  //Workaround for bug: 11522.
  mixin template resultsFileInitMixin() {

    private void initResultsFile() {
    
      _resultsFile = std.stdio.stdout;
    
    }

  }

  /**
    A mixin that generate an optional flagged argument on the command line for specifying where to put the results.
    Note that this argument should only be used when processing a single file.
  */
  mixin template resultsFileMixin() {

    private std.stdio.File _resultsFile;
    mixin getter!_resultsFile;
    
    mixin resultsFileInitMixin;  
    
    mixin argumentMixin!(
      _resultsFile,
      "file( 
        \"--rf\",
        \"Results file. This is where the program prints the results. Default is stdout.\",
        _resultsFile, 
        \"w\" 
      )"  
    );

  }

  /**
    An optional flagged argument for setting the verbosity of the program.
  */
  mixin template verbosityMixin() {

    private ubyte _verbosity = 0;  
    mixin getter!_verbosity;
    
    mixin argumentMixin!( 
      _verbosity,
      "value( 
        \"-v\", 
        \"Verbosity level. Default is \" ~ std.conv.to!string( _verbosity ) ~ \".\", 
        _verbosity        
      )"
    );
    
  }

  /**
    An optional flagged argument for redirecting the program output (messages to the user, not the same as
    the results file).
  */
  mixin template outFileMixin() {
    
    import std.stdio;

    private std.stdio.File _outFile;
    mixin getter!_outFile;
    
    mixin argumentMixin!( 
      _outFile, 
      "file( 
        \"--of\", 
        \"Output file. This is where the program emits statements. Default is stdout.\", 
        _outFile, 
        \"w\" 
      )" 
    );
    
  }  

  /**
    An optional flagged argument that sets whether or not the results are to be printed or just silently
    compiled.
  */
  mixin template printResultsMixin() {

    private bool _printResults = true;
    mixin getter!_printResults;
    
    mixin argumentMixin!( 
      _printResults, 
      "toggle( \"--no-res\", \"Prevents the results from being printed.\", _printResults )" 
    ); 

  }    
    
  /**
    An optional flagged argument for setting the maximum number of results to keep.
  */
  mixin template noResultsMixin() {
    
    size_t _noResults = 1000;    
    mixin getter!_noResults;
    
    mixin argumentMixin!(
      _noResults, 
      "value(  
        \"--nr \",  
        \"Number of results to keep in memory. Default is  \" ~ std.conv.to!string( _noResults ) ~  \". \",
        _noResults 
      )"
    );
    
  }
  
  /**
    An optional flagged argument that determines whether or not the execution time is to be shown.
  */  
  mixin template printTimeMixin() {
    bool _printTime = true;
    mixin getter!_printTime;

    mixin argumentMixin!(
      _printTime,
      "toggle(
        \"--no-time \",
        \"Removes the execution time from the results. \",
        _printTime 
      )"  
    );
  }  
    
  /**
    An optional flagged argument for setting the minimum segments length to be processed.
  */
  mixin template minLengthMixin() {

    size_t _minLength = 3;
    mixin getter!_minLength;
    
    mixin argumentMixin!(
      _minLength,
      "value(  
        \"--min \",  
        \"Minimum period length. Default is  \" ~ std.conv.to!string( _minLength ) ~  \". \", 
        _minLength 
      )"
    );

  }
    
  /**
    An optional flagged argument for setting the maximum segments length to be processed.
  */
  mixin template maxLengthMixin() {

    size_t _maxLength = size_t.max;
    mixin getter!_maxLength;

    mixin argumentMixin!(
      _maxLength,
      "value( 
        \"--max\",
        \"Maximum period length. Default is the biggest value held by a word. The mid sequence position is used if it is lower than this value.\",
        _maxLength 
      )"
    );
    
  }

  /**
    An optional flagged argument to change the length step between segments length.
  */
  mixin template lengthStepMixin() {

    size_t _lengthStep = 3;
    mixin getter!_lengthStep;

    mixin argumentMixin!(
      _lengthStep,
      "setter( 
        \"--single-step\",
        \"Sets the segment pair length step to be 1. The default is \" ~ std.conv.to!string( _lengthStep ) ~ \" instead of 3.\",
        _lengthStep,
        1u
      )"
    );
      
    
  }
   
  /**
    An optional flagged argument to set the number of concurrent thread to run at the same time.
  */
  mixin template noThreadsMixin() {

    size_t _noThreads = 1;
    mixin getter!_noThreads;
    
    //No arguments support as of today.
  }  


  /**
    Those are the algorithms used to process sequences and determine segments pairs distances.
  */
  enum Algo {
    standard = 0,   //Without optimizations.
    cache,          //Using a window frame cache.
    patterns,       //Reusing results based on nucleotides patterns.
    cachePatterns   //Both optimization at the same time.
  }

  //The strings used to identify the algorithms on the command line.
  package immutable string[ 4 ] algoStrings = [ "standard", "cache", "patterns", "cache-patterns" ];

  //The algorithms mapped with their strings for easy access.
  package immutable Algo[ string ] algosByStrings;
  static this() {
    algosByStrings = 
    [ 
      algoStrings[ Algo.standard ]: Algo.standard,
      algoStrings[ Algo.cache ]: Algo.cache, 
      algoStrings[ Algo.patterns ]: Algo.patterns,
      algoStrings[ Algo.cachePatterns ]: Algo.cachePatterns 
    ];

  }
    
  /**
    An optional flagged argument for setting the algorithms to use for the processing of one file or multiple sequences files.
  */
  mixin template algosMixin() {

    private std.container.Array!Algo _algos;  
    public @property auto algos() { return _algos[]; }
    
    //TODO: add the possibility to support more than one algorithm at once.
    mixin argumentMixin!(
      _algos,
      "flagged( 
        \"--algo\", 
        \"Sets the segment pair cost calculation algorithm. Possible values are \\\"standard\\\", \\\"cache\\\", \\\"patterns\\\" and \\\"cache-patterns\\\".\", 
        commonParser( mappedConverter( algosByStrings ), ( Algo algo ) { _algos.insertBack( algo ); } ),
        optional
      )"
    );

  } 
   
  /**
    An optional flagged argument that prints the configuration on screen for the user.
  */
  mixin template printConfigMixin() {
    
    bool _printConfig = false;  
    mixin getter!_printConfig;
    
    mixin argumentMixin!(
      _printConfig,
      "toggle( 
        \"--print-config\", 
        \"Prints the used configuration before starting the process if the flag is present.\",
        _printConfig 
      )"
    );

  }

  /**
    This mixin is a convenience function, named initAll(), that initializes all runtime
    defaults and values for the variables generated by using this module's mixins.
  */
  mixin template initAllMixin() {

    //Initializes every variable to its runtime value.
    void initAll() {
      
      foreach( member; __traits( allMembers, typeof( this ) ) ) {
      
        debug( mixins ) {
        
          pragma( msg, "processing member " ~ member );
        
        }
      
        enum call = "init!( \"" ~ member ~ "\" )()";
        enum hasInit = __traits( compiles, mixin( call ) );
        
        debug( mixins ) {
        
          pragma( msg, "has init? " ~ std.conv.to!string( hasInit ) );
        
        }
        
        static if( hasInit ) {
        
          mixin( call ~ ";" );
        
        } else {
        
          static assert( !isArgumentName!member, member );
        
        }
      
      }
    
    }

  }
  
  unittest {

    struct Toto {

      mixin sequencesFileMixin;
      mixin printConfigMixin;
      mixin algosMixin;
      mixin resultsFileMixin;
    
      mixin initAllMixin;  
    }

    Toto t;
    
    t.initAll();
    
    assert( t._sequencesFileArg !is null );
    assert( t._algosArg !is null );
    assert( t._printConfigArg !is null );
    assert( t._resultsFile == std.stdio.stdout ); //Fails because no support for field runtime defaults so far.
    assert( t._resultsFileArg !is null );
    
  }  

  
  /*********************************************************************************************************
    Utilities.
  *********************************************************************************************************/


  template dummy( string s ) {}

  /**
    Determines if the given expression is a string literal. Returns true if that is the case,
    false otherwise. Returns false if it's a type.
  */
  template isStringLiteral( alias s ) {
    enum isStringLiteral = __traits( compiles, dummy!s );
  }
  ///Ditto.
  template isStringLiteral( T ) {
    enum isStringLiteral = false;
  }

  /**
    Returns the string name of the identifier as provided by __traits( identifier, var ).
  */
  template identifier( alias var ) {
    enum identifier = __traits( identifier, var );  
  }


  unittest {
    static assert( isStringLiteral!"toto" );
    static assert( !isStringLiteral!int );
    string toto = "";
    static assert( !isStringLiteral!toto );
    static assert( identifier!toto == "toto" );
  }

  /**
    Takes a variable name and generates a standardized argument name
    corresponding to the variable. More specifically, "Arg" is appended 
    at the end of the name provided.
    
    So an argument for the field "myVar", for example, will be named
    "myVarArg". A field named "anArgArg" will become "anArgArgArg"...
    to be used intelligently.
  */
  template argumentNameOf( string member ) {

    //Append "Arg".
    enum argumentNameOf = member ~ "Arg";
        
  }
  
  /**
    Returns true if the provided name ends with "Arg", false otherwise.  
    Any name generated with argumentNameOf is guaranteed to return true.
  */
  template isArgumentName( string name ) {
    
    enum isArgumentName = std.string.endsWith( name, "Arg" );
    
  }

  unittest {
    
    static assert( argumentNameOf!"myVar" == "myVarArg" );
    static assert( argumentNameOf!"anArgArg" == "anArgArgArg" );
  
    static assert( isArgumentName!"Arg" );
    static assert( isArgumentName!"_Arg" );
    static assert( isArgumentName!"myVarArg" );
    static assert( isArgumentName!"anArgArgArg" );
    static assert( isArgumentName!( argumentNameOf!( "any string really" ) ) );
    
    static assert( !isArgumentName!"toto" );
  
  }
  
  
  /**
    This mixin generates an argument based on the provided variable. Note the the first
    value passed as a parameter must be a symbol, the type of the argument is determined
    by the return type of the factory function. It delegates the work to the other mixin,
    which should not be called by the user directly. This template is to be preferred because
    it formats the argument before passing them on.    
  */
  mixin template argumentMixin( alias name, string factoryFunction ) {
   
    mixin argumentMixinWithType!( argumentNameOf!( identifier!name ), mixin( "typeof( " ~ factoryFunction ~ " )" ), factoryFunction );
    
  }

  /**
    Takes a variable representing an argument, its type and the factory function
    provided as a string that will be used to instantiate it.
    The variable is declared private. It also generates a private init function in case
    the mixin is used in an environment that does not support runtime initialization
    (a struct). The init function is called init, and it is a template function
    whose argument is the name of the variable just generated, which the same as the
    name passed, as such:
    
      private void init( string s )() if( s == name ) {
      
        mixin( name ~ " = " ~ factoryFunction ~ ";" );
      
      }    
  */
  mixin template argumentMixinWithType( string name, T, string factoryFunction ) {
    
    //The argument variable generated.
    mixin( "private T " ~ name ~ ";" );
    
    debug( mixins ) {
    
      pragma( msg, "generating init for " ~ name );
    
    }
    
    //The initialization template function using the factory function provided. 
    //Must be instantiated with the variable name.
    private void init( string s )() if( s == name ) {
      
      mixin( name ~ " = " ~ factoryFunction ~ ";" );
    
    }

  }

  
  /**
    Generates a getter function for the given variable. The variable must hold the symbol and not be a string
    (a way to ensure the variable exists).
    
    It assumes that the given symbol name starts with "_".
  */
  mixin template getter( alias var ) {
    
    static assert( identifier!var[ 0 ] == '_' );
    
    mixin( "public @property auto " ~ ( identifier!( var ) )[ 1 .. $ ] ~ "() { return " ~ identifier!var ~ "; } " );
    
  }
  
}

 
 
