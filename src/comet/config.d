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
import std.container;
import std.range: isForwardRange;

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

/**
  The program can run in four modes. The first one being the processing of a single sequences file.
  There is a mode to generate references results to use for regression testing.
  The testing mode is used to make sure the new results are equivalent to the previous ones.
  The last mode is used to compare different measurements.
*/
enum Mode {
  normal,
  generateReferences,
  runTests,
  compileMeasures
}

struct Run {
private:
  File _resultsFile;
  Algo _algorithm;
  Config _cfg;
  
  this( Config cfg, File res, Algo rithm ) {
    _cfg = cfg;
    _resultsFile = res;
    _algorithm = rithm;
  }
public:
  @property auto resultsFile() { return _resultsFile; }
  @property auto algorithm() { return _algorithm; }  
  auto opDispatch( string meth, T... )( T args ) {
    return mixin( "_cfg." ~ meth )( args );
  }
}

struct FileRuns( Range ) if( isForwardRange!Range ) {
private:
  File _sequencesFile;
  Config _cfg;
  Range _algos;
  
  this( Config cfg, File sequencesFile, Range algos  ) {
    _sequencesFile = sequencesFile;
    _cfg = cfg;
    _algos = algos;
  }
public:
  @property bool empty() {
    return _algos.empty();
  }
  @property auto front() {
    return Run( _cfg, _cfg.resultsFileFor( _sequencesFile ), _algos.front() );
  }
  @property auto save() {
    return this;
  }
  void popFront() {
    _algos.popFront();
  }
  
  @property auto sequencesFile() {
    return _sequencesFile;
  }
}

private auto fileRuns( Range )( Config cfg, File seqFile, Range algos ) if( isForwardRange!Range ) {
  return FileRuns!Range( cfg, seqFile, algos );
}

struct Runs( Range ) if( isForwardRange!Range ) {
private:
  Range _sequencesFiles;
  Config _cfg;
  
  this( Config cfg, Range seqFiles ) {
    _cfg = cfg;
    _sequencesFiles = seqFiles;
  }
  
public:
  @property bool empty() {
    return _sequencesFiles.empty();
  }
  @property auto front() {
    return fileRuns( _cfg, _sequencesFiles.front(), _cfg.algos );
  }
  @property auto save() {
    return this;
  }
  void popFront() {
    _sequencesFiles.popFront();
  }
}

private auto runs( Range )( Config cfg, Range sequencesFiles ) if( isForwardRange!Range ) {
  return Runs!Range( cfg, sequencesFiles );
}



/**
  Program configuration data.
  Initialized to default value.
  Note that this should only be read by the rest of the program and never modified.
*/
class Config {
  string PROGRAM_NAME;
  
  public auto programRuns() {
    return runs( this, sequencesFiles ); 
  }

  private {
    Flagged _noResultsArg;
    Flagged _minPeriodArg;
    Flagged _maxPeriodArg;
    Flagged _singleStepArg;
    Flagged _verbosityLvlArg;
    Flagged _printConfigArg;
    Flagged _printTimeArg;
    Flagged _printResultsArg;
    Flagged _algorithmArg;    
    Flagged _seqDirArg;
    Flagged _resDirArg;
    Flagged _outFileArg;
    Flagged _seqFileArg;
    Flagged _resFileArg;
    Flagged _timeFileArg;
    IndexedLeft _script;    
    
    void initFlags() {
      _noResultsArg = value( "--nr", "Number of results to keep in memory. Default is " ~ _noResults.to!string() ~ ".", _noResults );
      _minPeriodArg = value( "--min", "Minimum period length. Default is " ~ _minPeriod.to!string() ~ ".", _minPeriod );
      _maxPeriodArg = 
        value( 
          "--max",
          "Maximum period length. Default is " ~ _minPeriod.to!string() ~ ". The mid sequence position is used if it is lower than this value.",
          _maxPeriod 
        );
      _singleStepArg = 
        setter( 
          "--single-step",
          "Sets the segment pair length step to be 1 instead of 3.",
          _periodStep,
          1u
        );
      _verbosityLvlArg = value( "-v", "Verbosity level. Default is " ~ _verbosity.to!string ~ ".", _verbosity );
      _printConfigArg = toggle( "--print-config", "Prints the used configuration before starting the process if the flag is present.", _printConfig );
      _printTimeArg = toggle( "--no-time", "Removes the execution time from the results.", _printTime );
      _printResultsArg = toggle( "--no-res", "Prevents the results from being printed.", _printResults );
      _algorithmArg = 
        flagged( 
          "--algo", 
          "Sets the duplication cost calculation algorithm. Possible values are \"standard\", \"cache\", \"patterns\" and \"cache-patterns\".", 
          commonParser( mappedConverter( algosByStrings ), ( Algo algo ) { _algos.insertBack( algo ); } )
        );        
      _seqDirArg = dir( "--sd", "Sequences directory. This flag is mandatory.", _sequencesDir );       
      _resDirArg = dir( "--rd", "Results directory. This flag is mandatory.", _resultsDir );
      _outFileArg = file( "--of", "Output file. This is where the program emits statements. Default is stdout.", _outFile, "w" );
      _seqFileArg = flagged( 
        "-s", 
        "Sequences file. This flag is mandatory.", 
        commonParser( fileConverter( "r" ), ( File f ) { _sequencesFiles.insertBack( f );  } )
        );
      _resFileArg = file( "--rf", "Results file. This is where the program prints the results. Default is stdout.", _resultsFile, "w" );
      _timeFileArg = file( "--tf", "Time file. This is where the time will be printed. Default is stdout.", _timeFile, "w" );
      _script = indexedLeft( 
        0, 
        "script", 
        "This argument lets the user use a predefined script.", 
        new class ParserI {
          override string[] take( string[] args ) {
            if( !args.length ) return args;
            
            switch( args[ 0 ] ) {
              case "generate-references":
                _mode = Mode.generateReferences;
                
                auto genRefParser = generateReferencesParser();           
                return genRefParser.parse( args );
                break;            
              default:
                return args;
            }     
            assert( false );          
          }
          
          override void store() {}
          override void assign() {}
        }
      );
      _script.optional;
    }
  }

  Parser generateReferencesParser() {
    auto genRefParser = new Parser();
    genRefParser.name = PROGRAM_NAME ~ " generate-references";    
    genRefParser.add(
      _seqDirArg,
      _resDirArg,
      _verbosityLvlArg,
      _outFileArg,
      _printTimeArg,
      _printConfigArg,
    );           
    genRefParser.mandatory( _seqDirArg );
    genRefParser.mandatory( _resDirArg ); 
    
    return genRefParser;  
  }
    
  private Mode _mode = Mode.normal;
  @property public Mode mode() { return _mode; }

  private Array!File _sequencesFiles;
  private string _sequencesDir;
  @property public auto sequencesFiles() { 
    import std.file;
    import std.algorithm; 
    
    switch( _mode ) {
      case Mode.generateReferences:
        foreach( file; dirEntries( _sequencesDir, SpanMode.depth ).map!( a => File( a, "r" ) ) ) {
          _sequencesFiles.insertBack( file );
        }
        
        break;
      default:
        return _sequencesFiles[];     
    } 
    return _sequencesFiles[];
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
  
  private Array!Algo _algos;  
  @property public auto algos() { return _algos[]; }
  
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
        writeln( "Sequences files: ", _sequencesFiles[].map!( a => a.fileName() ) );
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
      
      writeln( "Algorithms: ", _algos[].map!( algo => algoStrings[ algo ] ) );
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
    _algos.reserve( algoStrings.length );
    _algos.insertBack( Algo.standard );
    initFlags();   
    PROGRAM_NAME = commandName( tokens );
    
    //Normal mode parser.
    auto parser = new Parser();
    parser.add(
      _script,
      _seqFileArg,
      _verbosityLvlArg,
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
    
    parser.mandatory( _seqFileArg );
    mutuallyExclusive( _printResultsArg, _resFileArg );
    mutuallyExclusive( _printTimeArg, _timeFileArg );
    
    parser.parse( tokens );
    
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