/**
  Command line interface of the program.
  It is responsible for setting up the flags and parsing the user's
  input, guaranteeing a usable state for the system.
*/
module comet.config;

import comet.cli.all;

import std.exception;
import std.conv;
import std.stdio;

/**
  Those are the algorithms used to process sequences and determine segment pairs distances.
*/
enum Algo {
  standard = 0,
  cache,
  patterns,
  cachePatterns
}

//The strings used to identify the algorithms on the command line.
private immutable string[ 4 ] algoStrings = [ "standard", "cache", "patterns", "cache-patterns" ];

//The algorithms mapped with their strings for easy access.
private immutable Algo[ string ] algosByStrings;
static this() {
  algosByStrings = 
  [ 
    algoStrings[ Algo.standard ]: Algo.standard,
    algoStrings[ Algo.cache ]: Algo.cache, 
    algoStrings[ Algo.patterns ]: Algo.patterns,
    algoStrings[ Algo.cachePatterns ]: Algo.cachePatterns 
  ];
}

enum Mode {
  normal,
  batch,
  generateReferences,
  runTests,
  compileMeasures
}

/**
  Program configuration data.
  Initialized to default value.
  Note that this should only be read by the rest of the program and never modified.
*/
struct Config {
    
  private Mode _mode = Mode.normal;
  @property public Mode mode() { return _mode; }

  private File[] _sequencesFiles;
  private string _sequencesDir;
  @property public auto sequencesFiles() { 
    import std.array;
    import std.file;
    import std.algorithm; 
    
    switch( _mode ) {
      case Mode.generateReferences:
        auto files = new File[ dirEntries( _sequencesDir, SpanMode.depth ).count() ];
        
        int i = 0;
        foreach( file; dirEntries( _sequencesDir, SpanMode.depth ).map!( a => File( a, "r" ) ) ) {
          files[ i ] = file;
          ++i;
        }
        
        return files[];
      default:
        return _sequencesFiles[];     
    } 
  }
  
  private ubyte _verbosity = 0;  
  @property public ubyte verbosity() { return _verbosity; }
  
  private File _outFile;
  @property public File outFile() { return _outFile; }
  
  private bool _printResults = true;
  @property public bool printResults() { return _printResults; }
  
  private size_t _noResults = 1000;    
  @property public size_t noResults() { return _noResults; }
  
  private File _resultsFile;
  private string _resultsDir;
  
  public File resultsFileFor( File sequencesFile ) {
    import std.path;
    
    switch( mode ) {
      case Mode.generateReferences:
        return File( _resultsDir ~ sequencesFile.name().baseName().stripExtension() ~ ".reference", "w" );
      default:
        return _resultsFile;
    }
  }
  
  
  private bool _printTime = true;
  @property public bool printTime() const { return _printTime; }
  
  private File _timeFile;
  @property public File timeFile() { return _timeFile; }
  
  private size_t _minPeriod = 3;
  @property public size_t minPeriod() const { return _minPeriod; }
  
  private size_t _maxPeriod = size_t.max;
  @property public size_t maxPeriod() const { return _maxPeriod; }
  
  private size_t _periodStep = 3;
  @property public size_t periodStep() const { return _periodStep; }
  
  private size_t _noThreads = 1;
  @property public size_t noThreads() const { return _noThreads; }
  
  private Algo _algo = Algo.standard;  
  @property public Algo algo() const { return _algo; }
  
  private bool _printConfig = false;  
  @property public bool printConfig() const { return _printConfig; }
 
  
 
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
      
      if( _mode == Mode.normal ) {
        writeln( "Sequences files: ", _sequencesFiles.map!( a => a.fileName() ) );
      } else {
        writeln( "Sequences dir: ", _sequencesDir );
      }
      
      writeln( "Print results: ", _printResults );
      writeln( "Number of results: ", _noResults );
      
      if( _mode == Mode.normal ) {
        writeln( "Results file: ", _resultsFile.fileName() );
      } else {
        writeln( "Results dir: ", _resultsDir );
      }
      
      writeln( "Print time: ", _printTime );
      writeln( "Time file: ", _timeFile.fileName() );
      
      writeln( "Algorithm: ", algoStrings[ _algo ] );
      writeln( "Minimum period: ", _minPeriod );
      writeln( "Maximum period: ", _maxPeriod );
      writeln( "Period step: ", _periodStep );
      
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
  public void parse( string[] tokens ) {
    //Run time defaults.
    _timeFile = stdout;
    _outFile = stdout;
    _resultsFile = stdout;
    _sequencesFiles = new File[ 1 ];
    _sequencesFiles[ 0 ] = stdout;
    
    
    auto noResults = value( "--nr", "Number of results to keep in memory. Default is " ~ _noResults.to!string() ~ ".", _noResults );
    auto minPeriod = value( "--min", "Minimum period length. Default is " ~ _minPeriod.to!string() ~ ".", _minPeriod );
    auto maxPeriod = 
      value( 
        "--max",
        "Maximum period length. Default is " ~ _minPeriod.to!string() ~ ". The mid sequence position is used if it is lower than this value.",
        _maxPeriod 
      );
    auto singleStep = 
      setter( 
        "--single-step",
        "Sets the segment pair length step to be 1 instead of 3.",
        _periodStep,
        1u
      );
    auto verbosityLvl = value( "-v", "Verbosity level. Default is " ~ _verbosity.to!string ~ ".", _verbosity );
    auto printConfig = toggle( "--print-config", "Prints the used configuration before starting the process if the flag is present.", _printConfig );
    auto printTime = toggle( "--no-time", "Removes the execution time from the results.", _printTime );
    auto printResults = toggle( "--no-res", "Prevents the results from being printed.", _printResults );
    auto algo = 
      mapped( 
        "--algo", 
        "Sets the duplication cost calculation algorithm. Possible values are \"standard\", \"cache\", \"patterns\" and \"cache-patterns\".", 
        _algo,
        algosByStrings
      );
      
    auto seqDir = dir( "--sd", "Sequences directory. This flag is mandatory.", _sequencesDir );
     
    auto resDir = dir( "--rd", "Results directory. This flag is mandatory.", _resultsDir );
  
    auto outFile = file( "--of", "Output file. This is where the program emits statements. Default is stdout.", _outFile, "w" );
  
    auto genRefParser = new ProgramParser();
    genRefParser.name = commandName( tokens ) ~ " generate-references";
    
    genRefParser.add(
      seqDir,
      resDir,
      verbosityLvl,
      outFile,
      printTime,
      printConfig,
    );           
    genRefParser.mandatory( seqDir );
    genRefParser.mandatory( resDir );
    
    auto genRef = custom( "generate-references", "Boom", genRefParser );
        
             
    auto seqFile = file( "-s", "Sequences file. This flag is mandatory.", _sequencesFiles[ 0 ], "r" );
    auto resFile = file( "--rf", "Results file. This is where the program prints the results. Default is stdout.", _resultsFile, "w" );
    auto timeFile = file( "--tf", "Time file. This is where the time will be printed. Default is stdout.", _timeFile, "w" );
    
    //Normal mode parser.
    auto parser = new ProgramParser();
    parser.name = commandName( tokens );    
    parser.add(
      genRef,
      seqFile,
      verbosityLvl,
      outFile,
      printResults,
      resFile,
      printTime,
      timeFile,
      noResults,
      minPeriod,
      maxPeriod,
      singleStep,
      printConfig,
      algo      
    );
    
    parser.mandatory( seqFile );
    parser.mutuallyExclusive( printResults, resFile );
    parser.mutuallyExclusive( printTime, timeFile );
    
    parser.parse( tokens );
    
    if( genRef.used ) {
      _mode = Mode.generateReferences;
    }    
      
    
    //The minimum segment pair length must be below the maximum.
    enforce( _minPeriod <= _maxPeriod, "The minimum period value: " ~ _minPeriod.to!string() ~ " is above the maximum: " ~ _maxPeriod.to!string() );  
    assert( _periodStep == 1 || _periodStep == 3 );
      
    if( _printConfig ) {
      print();
    }  
  }
}

//Small helper function to help print configuration files in a user friendly fashion.
private string fileName( File file ) {
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