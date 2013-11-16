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
import std.file;
import std.algorithm; 

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
  standard,
  generateReferences,
  compareResults,
  runTests,
  compileMeasures
}

/**
  Program configuration data.
  Initialized to default value.
  Note that this should only be read by the rest of the program and never modified.
*/
class Config {
public:
  @property public auto sequencesFiles() { 
    return _sequencesFiles[];
  }

protected:

  Mode _mode;
  @property public Mode mode() { return _mode; }

  Array!File _sequencesFiles;
    
  ubyte _verbosity = 0;  
  @property public ubyte verbosity() { return _verbosity; }
  
  File _outFile;
  @property public File outFile() { return _outFile; }
  
  bool _printResults = true;
  @property public bool printResults() { return _printResults; }
  
  size_t _noResults = 1000;    
  @property public size_t noResults() { return _noResults; }
  
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
  
  
  bool _printTime = true;
  @property public bool printTime() const { return _printTime; }
  
  File _timeFile;
  @property public File timeFile() { return _timeFile; }
  
  size_t _minPeriod = 3;
  @property public size_t minPeriod() const { return _minPeriod; }
  public alias minLength = minPeriod;
  
  size_t _maxPeriod = size_t.max;
  @property public size_t maxPeriod() const { return _maxPeriod; }
  public alias maxLength = maxPeriod;
  
  size_t _periodStep = 3;
  @property public size_t periodStep() const { return _periodStep; }
  public alias lengthStep = periodStep;
  
  size_t _noThreads = 1;
  @property public size_t noThreads() const { return _noThreads; }
  
  Array!Algo _algos;  
  @property public auto algos() { return _algos[]; }
  
  bool _printConfig = false;  
  @property public bool printConfig() const { return _printConfig; }
  
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
  IndexedRight _seqFileArg;
  
  Flagged _noResultsArg;
  Flagged _minPeriodArg;
  Flagged _maxPeriodArg;
  Flagged _singleStepArg;
  Flagged _verbosityLvlArg;
  Flagged _printConfigArg;
  Flagged _printTimeArg;
  Flagged _printResultsArg;
  Flagged _algorithmArg;   
  Flagged _epsilonArg;
    
  IndexedRight _seqDirArg;
  IndexedRight _resDirArg;
  IndexedRight _refDirArg;
  IndexedRight _filesToCompareArg;
  
  Flagged _outFileArg;
  
  Flagged _resFileArg;
  Flagged _timeFileArg;
     
  
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
    
    
    _outFileArg = file( "--of", "Output file. This is where the program emits statements. Default is stdout.", _outFile, "w" );
    _seqFileArg = indexedRight( 
      0u,
      "sequencesFile", 
      "This argument is the file holding the sequences to process.", 
      commonParser( fileConverter( "r" ), ( File f ) { _sequencesFiles.insertBack( f );  } )
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
      _verbosityLvlArg,
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
    
    mutuallyExclusive( _printResultsArg, _resFileArg );
    mutuallyExclusive( _printTimeArg, _timeFileArg );
    
    return standardParser;
    
  }
  
  auto generateReferencesParser() {
    
    auto genRefParser = parser;
    genRefParser.name = PROGRAM_NAME ~ " generate-references";    
    genRefParser.add(
      _verbosityLvlArg,
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
  public void parse( string[] tokens ) out {
  
    assert( _periodStep == 1 || _periodStep == 3 );
    
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
    enforce( _minPeriod <= _maxPeriod, "The minimum length value: " ~ _minPeriod.to!string() ~ " is above the maximum length: " ~ _maxPeriod.to!string() );  
          
    if( _printConfig ) {

      print();

    }
    
  }
}

auto configFor( string[] args ) {
  return new Config( args );
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

unittest {
  import std.stdio;
  
  auto name = fileName( stdout );
  assert( name == "stdout" );
  name = fileName( stderr );
  assert( name == "stderr" );
  name = fileName( stdin );
  assert( name == "stdin" );
}