/**
  Command line interface of the program.
  It is responsible for setting up the flags and parsing the user's
  input, guaranteeing a usable state for the system.
*/
module comet.config;

import comet.flags;

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

private Mode getMode( string[] args ) {
  return getMode( args[ 1 ] );
}
private Mode getMode( string mode ) {
  switch( mode ) {
    case "batch":
      return Mode.batch;
    case "gen-references":
      return Mode.generateReferences;
    case "run-tests":
      return Mode.runTests;
    case "compile-measures":
      return Mode.compileMeasures;
    default:
      return Mode.normal;  
  }
}

/**
  Program configuration data.
  Initialized to default value.
  Note that this should only be read by the rest of the program and never modified.
*/
struct Config {
  Mode mode = Mode.normal;

  File[] sequencesFiles;
  
  ubyte verbosity = 0;  
  File outFile;
    
  bool printResults = true;
  size_t noResults = 1000;    
  File[] resultsFiles;
  
  bool printTime = true;
  File timeFile;
  
  size_t minPeriod = 3;
  size_t maxPeriod = size_t.max;
  size_t periodStep = 3;
  size_t noThreads = 1;
  Algo algo = Algo.standard;  
  
  bool printConfig = false;  
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

/**
  Prints the program configuration to the standard output.
  Typically, it is to be used on demand by the user.
*/
void print( ref Config cfg ) {
  import std.algorithm;
  
  with( cfg.outFile ) {
    writeln( "-------------------------------------------------" );
    writeln( "Configuration:" );
    
    writeln( "Verbosity level: ", cfg.verbosity );
    writeln( "Sequences files: ", cfg.sequencesFiles.map!( a => a.fileName() ) );
    
    writeln( "Print results: ", cfg.printResults );
    writeln( "Number of results: ", cfg.noResults );
    writeln( "Results files: ", cfg.resultsFiles.map!( a => a.fileName() ) );
    
    writeln( "Print time: ", cfg.printTime );
    writeln( "Time file: ", cfg.timeFile.fileName() );
    
    writeln( "Algorithm: ", algoStrings[ cfg.algo ] );
    writeln( "Minimum period: ", cfg.minPeriod );
    writeln( "Maximum period: ", cfg.maxPeriod );
    writeln( "Period step: ", cfg.periodStep );
    
    writeln( "Print configuration: ", cfg.printConfig );    
    
    writeln( "-------------------------------------------------" );
  }
}



private void initializeAndParse( ref Config cfg, string[] tokens ) {
  immutable string PROGRAM_NAME = "comet";
  
  cfg.timeFile = stdout;
  cfg.outFile = stdout;
  
  auto parser = Parser( tokens, "N/A" );

  auto noResults = Flag.value( "--nr", "Number of results to keep in memory. Default is " ~ cfg.noResults.to!string() ~ ".", cfg.noResults );
  auto minPeriod = Flag.value( "--min", "Minimum period length. Default is " ~ cfg.minPeriod.to!string() ~ ".", cfg.minPeriod );
  auto maxPeriod = 
    Flag.value( 
      "--max",
      "Maximum period length. Default is " ~ cfg.minPeriod.to!string() ~ ". The mid sequence position is used if it is lower than this value.",
      cfg.maxPeriod 
    );
  auto singleStep = 
    Flag.setter( 
      "--single-step",
      "Sets the segment pair length step to be 1 instead of 3.",
      cfg.periodStep,
      1u
    );
  auto verbosityLvl = Flag.value( "-v", "Verbosity level. Default is " ~ cfg.verbosity.to!string ~ ".", cfg.verbosity );
  auto printConfig = Flag.toggle( "--print-config", "Prints the used configuration before starting the process if the flag is present.", cfg.printConfig );
  auto printTime = Flag.toggle( "--no-time", "Removes the execution time from the results.", cfg.printTime );
  auto printResults = Flag.toggle( "--no-res", "Prevents the results from being printed.", cfg.printResults );
  auto algo = 
    Flag.mapped( 
      "--algo", 
      "Sets the duplication cost calculation algorithm. Possible values are \"standard\", \"cache\", \"patterns\" and \"cache-patterns\".", 
      cfg.algo,
      algosByStrings
    );

  
  cfg.mode = getMode( tokens );
  
  switch( cfg.mode ) {
    case Mode.normal:
      cfg.sequencesFiles = new File[ 1 ];
      cfg.sequencesFiles[ 0 ] = stdout;
      cfg.resultsFiles = new File[ 1 ];
      cfg.resultsFiles[ 0 ] = stdout;
      
    
      auto seqFile = Flag.file( "-s", "Sequences file. This flag is mandatory.", cfg.sequencesFiles[ 0 ], "r" );
      auto outFile = Flag.file( "--of", "Output file. This is where the program emits statements. Default is stdout.", cfg.outFile, "w" );
      auto resFile = Flag.file( "--rf", "Results file. This is where the program prints the results. Default is stdout.", cfg.resultsFiles[ 0 ], "w" );
      auto timeFile = Flag.file( "--tf", "Time file. This is where the time will be printed. Default is stdout.", cfg.timeFile, "w" );
      
      parser.name = PROGRAM_NAME;
      
      parser.add(
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
      
      parser.parse();    
      break;
  
    case Mode.generateReferences:
      //TODO create a variable to hold the name of the gen-references.
      parser.name = PROGRAM_NAME ~ " gen-references";
      
      
      string sequencesDir;
      auto seqDir = Flag.dir( "--sd", "Sequences directory. This flag is mandatory.", sequencesDir );
      
      string resultsDir;
      auto resDir = Flag.dir( "--rd", "Results directory. This flag is mandatory.", resultsDir );
    
      auto outFile = Flag.file( "--of", "Output file. This is where the program emits statements. Default is stdout.", cfg.outFile, "w" );
    
      parser.add(
        seqDir,
        resDir,
        verbosityLvl,
        outFile,
        printTime,
        printConfig,
      );
             
      parser.mandatory( seqDir );
      parser.mandatory( resDir );
      parser.args = parser.args[ 1 .. $ ];
      
      parser.parse();    
      break;
   
    default:
      assert( false, "unknown mode: " ~ cfg.mode.to!string );
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
void parse( ref Config cfg, string[] tokens ) {
  initializeAndParse( cfg, tokens );       
    
  //The minimum segment pair length must be below the maximum.
  enforce( cfg.minPeriod <= cfg.maxPeriod, "The minimum period value: " ~ cfg.minPeriod.to!string() ~ " is above the maximum: " ~ cfg.maxPeriod.to!string() );  
  assert( cfg.periodStep == 1 || cfg.periodStep == 3 );
    
  if( cfg.printConfig ) {
    cfg.print();
  }  
}