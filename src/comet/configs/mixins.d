module comet.configs.mixins;



import comet.cli.all;

public import std.conv;
import std.stdio;
import std.string;


private template dummy( string s ) {}

template isStringLiteral( alias s ) {
  enum isStringLiteral = __traits( compiles, dummy!s );
}
template isStringLiteral( T ) {
  enum isStringLiteral = false;
}

/**
  Up to now, supports strings and variable symbols.
*/
template identifier( alias var ) {
  static if( isStringLiteral!var ) {
    enum identifier = var;
  } else{
    enum identifier = __traits( identifier, var );
  }
}


unittest {
  static assert( isStringLiteral!"toto" );
  static assert( !isStringLiteral!int );
  string toto = "";
  static assert( !isStringLiteral!toto );
  static assert( identifier!toto == "toto" );
}


mixin template argumentMixin( alias name, string factoryFunction ) {
 
  mixin argumentMixinT!( argumentNameOf!( identifier!name ), mixin( "typeof( " ~ factoryFunction ~ " )" ), factoryFunction );
  
}


mixin template argumentMixinT( string name, T, string factoryFunction ) {
  mixin( "private T " ~ name ~ ";" );
  
  debug( mixins ) {
  
    pragma( msg, "generating init for " ~ name );
  
  }
  
  private void init( string s )() if( s == name ) {
    
    mixin( name ~ " = " ~ factoryFunction ~ ";" );
  
  }

}

template argumentNameOf( string member ) {
  static if( isArgumentName!( member ) ) {
    enum argumentNameOf = member;
  } else {
    enum argumentNameOf = member ~ "Arg";
  }
}
template isArgumentName( string name ) {
  enum isArgumentName = name.endsWith( "Arg" );
}



/**
  Assumes that it starts with _
*/
mixin template getter( alias var ) {
  mixin( "public @property auto " ~ ( identifier!( var ) )[ 1 .. $ ] ~ "() { return " ~ identifier!var ~ "; } " );
}

mixin template sequencesFilesMixin() {
  import std.container;
  import std.stdio;
  
  private Array!File _sequencesFiles;  

  public @property auto sequencesFiles() { return _sequencesFiles[]; }
  
  mixin argumentMixin!(
    _sequencesFiles,
    "indexedRight( 
      0u,
      \"sequencesFile\", 
      \"This argument is the file holding the sequences to process.\", 
      commonParser( fileConverter( \"r\" ), ( File f ) { _sequencesFiles.insertBack( f );  } )
    )"    
  ); 
  
}

mixin template sequencesDirMixin() {
  import std.container;
  import std.stdio;
  
  private Array!File _sequencesFiles;

  public @property auto sequencesFiles() { return _sequencesFiles[]; }
  
  mixin argumentMixin!(
    _sequencesFile,
    "indexedRight( 
      0,
      \"sequences directory\", 
      \"This argument indicates the directory where the sequences files are located.\", 
      commonParser(
        ( string[] args ) => args[ 0 ],
        ( string dir ) {         
          foreach( file; dirEntries( dir, SpanMode.shallow ).map!( a => File( a, \"r\" ) ) ) {
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
  
    _resultsFile = stdout;
  
  }

}

mixin template resultsFileMixin() {

  import std.stdio;

  private File _resultsFile;
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

mixin template verbosityMixin() {

  private ubyte _verbosity = 0;  
  mixin getter!_verbosity;
  
  mixin argumentMixin!( 
    _verbosity,
    "value( \"-v\", \"Verbosity level. Default is \" ~ _verbosity.to!string() ~ \".\", _verbosity )"
  );
  
}

mixin template outFileMixin() {
  
  import std.stdio;

  private File _outFile;
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

mixin template printResultsMixin() {

  private bool _printResults = true;
  mixin getter!_printResults;
  
  mixin argumentMixin!( 
    _printResults, 
    "toggle( \"--no-res\", \"Prevents the results from being printed.\", _printResults )" 
  ); 

}    
  
mixin template noResultsMixin() {
  size_t _noResults = 1000;    
  mixin getter!_noResults;
  
  mixin argumentMixin!(
    _noResults, 
    "value(  
      \"--nr \",  
      \"Number of results to keep in memory. Default is  \" ~ _noResults.to!string() ~  \". \",
      _noResults 
    )"
  );
  
}
  
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
  
mixin template minLengthMixin() {

  size_t _minLength = 3;
  mixin getter!_minLength;
  
  mixin argumentMixin!(
    _minLength,
    "value(  
      \"--min \",  
      \"Minimum period length. Default is  \" ~ _minLength.to!string() ~  \". \", 
      _minLength 
    )"
  );

}
  
mixin template maxLengthMixin() {

  size_t _maxLength = size_t.max;
  mixin getter!_maxLength;

  mixin argumentMixin!(
    _maxLength,
    "value( 
      \"--max\",
      \"Maximum period length. Default is \" ~ _maxLength.to!string() ~ \". The mid sequence position is used if it is lower than this value.\",
      _maxLength 
    )"
  );
  
}

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
  
mixin template noThreadsMixin() {

  size_t _noThreads = 1;
  mixin getter!_noThreads;
  
  //No arguments support as of today.
}  


/**
  Those are the algorithms used to process sequences and determine segment pairs distances.
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
  
mixin template algosMixin() {
  import std.container;

  Array!Algo _algos;  
  public @property auto algos() { return _algos[]; }
  
  mixin argumentMixin!(
    _algos,
    "flagged( 
      \"--algo\", 
      \"Sets the segment pair cost calculation algorithm. Possible values are \\\"standard\\\", \\\"cache\\\", \\\"patterns\\\" and \\\"cache-patterns\\\".\", 
      commonParser( mappedConverter( algosByStrings ), ( Algo algo ) { _algos.insertBack( algo ); } )
    )"
  );

} 
 
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

mixin template initAllMixin() {

  void initAll() {
    
    foreach( member; __traits( allMembers, typeof( this ) ) ) {
    
      debug( mixins ) {
      
        pragma( msg, "processing member " ~ member );
      
      }
    
      enum call = "init!( \"" ~ member ~ "\" )()";
      enum hasInit = __traits( compiles, mixin( call ) );
      
      debug( mixins ) {
      
        pragma( msg, "has init? " ~ hasInit.to!string() );
      
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

    mixin sequencesFilesMixin;
    mixin printConfigMixin;
    mixin algosMixin;
    mixin resultsFileMixin;
  
    mixin initAllMixin;  
  }

  Toto t;
  
  /+t.initAll();
  
  assert( t._sequencesFilesArg !is null );
  assert( t._algosArg !is null );
  assert( t._printConfigArg !is null );
  assert( t._resultsFile == stdout );
  assert( t._resultsFileArg !is null );+/
  
}  
 
/+  
 
  //Used when in compare results mode.
  Array!File _resultsToCompare;
  double _epsilon;
  public @property auto epsilon() { return _epsilon; }


  string PROGRAM_NAME;
  
  protected this( string[] args ) {
    initFlags();
    parse( args );
  }
  
  //Default standalone mode arguments.
  IndexedLeft _script; 
    
  Flagged _noResultsArg;
  
  Flagged _maxPeriodArg;
  Flagged _singleStepArg;
  
  Flagged _printConfigArg;
  Flagged _printTimeArg;
  
  Flagged _algorithmArg;   
  Flagged _epsilonArg;
    
  IndexedRight _seqDirArg;
  IndexedRight _resDirArg;
  IndexedRight _refDirArg;
  IndexedRight _filesToCompareArg;
  
  
  
  Flagged _resFileArg;
  Flagged _timeFileArg;
     
  
  void initFlags() {
    _noResultsArg = ;

       
   _seqDirArg = indexedRight( 
      0,
      "sequences directory", 
      "This argument indicates the directory where the sequences files are located.", 
      commonParser(
        ( string[] args ) => args[ 0 ],
        ( string dir ) {         
          foreach( file; dirEntries( dir, SpanMode.shallow ).map!( a => File( a, "r" ) ) ) {
            _sequencesFiles.insertBack( file );
          }
        } 
      ),
      mandatory
    );       
      
    _resDirArg = indexedRight( 
      1u,
      "results directory", 
      "Where the results will be stored.", 
      commonParser( dirConverter(), _resultsDir ),
      mandatory
    );
    
    _refDirArg = indexedRight( 
      1u,
      "references directory", 
      "Where the references are stored.", 
      commonParser( dirConverter(), _resultsDir ),
      mandatory
    );
    
    
    
    _resFileArg = file( "--rf", "Results file. This is where the program prints the results. Default is stdout.", _resultsFile, "w" );
    _timeFileArg = file( "--tf", "Time file. This is where the time will be printed. Default is stdout.", _timeFile, "w" );
    
      
  }

  Parser runTestsParser() {
    auto runTestsParser = new Parser();
    runTestsParser.name = PROGRAM_NAME ~ " run-tests";    
    runTestsParser.add(
      _seqDirArg,
      _refDirArg,
      _verbosityArg,
      _outFileArg,
      _printTimeArg,
      _printConfigArg,
    );           
    
    return runTestsParser;  
  }

  auto standardParser() {
    
    auto standardParser = parser();
    standardParser.name = PROGRAM_NAME;
    
    standardParser.add(
      _seqFileArg,
      _verbosityArg,
      _outFileArg,
      _printResultsArg,
      _resFileArg,
      _printTimeArg,
      _timeFileArg,
      _noResultsArg,
      _minPeriodArg,
      _maxPeriodArg,
      _singleStepArg,
      _printConfigArg,
      _algorithmArg
    );
    
    mutuallyExclusive( _printResultsArg, _resFileArg );
    mutuallyExclusive( _printTimeArg, _timeFileArg );
    
    return standardParser;
    
  }
  
  auto generateReferencesParser() {
    
    auto genRefParser = parser;
    genRefParser.name = PROGRAM_NAME ~ " generate-references";    
    genRefParser.add(
      _verbosityArg,
      _outFileArg,
      _printTimeArg,
      _printConfigArg,
      _seqDirArg,
      _resDirArg
    );           
    
    return genRefParser;  
  }
    
  auto compareResultsParser() {
  
  }
    
public: 
 
  /**
    Prints the program configuration to the standard output.
    Typically, it is to be used on demand by the user.
  */
  public void print() {
    import std.algorithm;
    
    with( _outFile ) {
      writeln( "-------------------------------------------------" );
      writeln( "Configuration:" );
      
      writeln( "Verbosity level: ", _verbosity );
      writeln( "Output file: ", _outFile );
      
      writeln( "Sequences files: ", _sequencesFiles[].map!( a => a.fileName() ) );
      
      writeln( "Print results: ", _printResults );
      writeln( "Number of results: ", _noResults );
      
      if( _mode == Mode.standard ) {
        writeln( "Results file: ", _resultsFile.fileName() );
      } else {
        writeln( "Results dir: ", _resultsDir );
      }
      
      writeln( "Print time: ", _printTime );
      writeln( "Time file: ", _timeFile.fileName() );
      
      writeln( "Algorithms: ", _algos[].map!( algo => algoStrings[ algo ] ) );
      writeln( "Minimum period: ", _minPeriod );
      writeln( "Maximum period: ", _maxLength );
      writeln( "Period step: ", _lengthStep );
      
      writeln( "Print configuration: ", _printConfig );    
      
      writeln( "-------------------------------------------------" );
    }
  }
  
  /**
    This function will get the arguments from the command line and initialize
    the configuration accordingly. When this function throws, the main program
    should not consider the configuration in a usable state and therefore
    abort.
    
    This function not only throws on error, but also if the user asked for the
    help menu (-h).
  */
  public void parse( string[] tokens ) out {
  
    assert( _lengthStep == 1 || _lengthStep == 3 );
    
  } body {
  
    //Run time defaults.
    _timeFile = stdout;
    _outFile = stdout;
    _resultsFile = stdout;
    _algos.reserve( algoStrings.length );
    _algos.insertBack( Algo.standard );
    PROGRAM_NAME = commandName( tokens );
    
    Parser parser;
    
    auto script = indexedLeft( 
      0u, 
      "script", 
      "This argument lets the user use a predefined script.", 
      new class ParserI {
      
        override string[] take( string[] args ) out {
        
          assert( parser !is null );
        
        } body {
        
          if( args.length ) { 
            
            switch( args[ 0 ] ) {
            
              case "generate-references":
                
                _mode = Mode.generateReferences;              
                parser = generateReferencesParser();           
                tokens = tokens[ 1 .. $ ];
                
                break;   
                
              case "run-tests":
              
                assert( false, "not implemented yet" );
                
              default:
              
                _mode = Mode.standard;
                parser = standardParser();
                
            }
          
          }
            
          //Whatever happens, don't parse anything else.
          return [];
            
        }
        
        override void store() {}
        override void assign() {}
        
      },      
      Usage.optional
      
    );  
    
    auto probe = comet.cli.all.parser();
    probe.add( script );
    //Only parse the first token.
    probe.parse( tokens[ 0 .. 2 ] );
    
    parser.parse( tokens );
    
       
    //The minimum segment pair length must be below the maximum.
    enforce( _minPeriod <= _maxLength, "The minimum length value: " ~ _minPeriod.to!string() ~ " is above the maximum length: " ~ _maxLength.to!string() );  
          
    if( _printConfig ) {

      print();

    }
    
  }
}

+/

/+
  File _resultsFile;
  string _resultsDir;
  
  public File resultsFileFor( File sequencesFile ) {
    import std.path;
    
    switch( mode ) {
      case Mode.generateReferences:
        return File( _resultsDir ~ sequencesFile.name().baseName().stripExtension() ~ ".reference", "w" );
      default:
        return _resultsFile;
    }
  }


+/