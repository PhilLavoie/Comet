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

enum Algo {
  standard = 0,
  cache,
  patterns,
  cachePatterns
}

private immutable string[ 4 ] algoStrings = [ "standard", "cache", "patterns", "cache-patterns" ];
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
  Program configuration data.
  Initialized to default value.
*/
struct Config {
  File sequencesFile;
  ubyte verbosity = 0;  
  File outFile;
  bool printResults = true;
  File resFile;
  bool printTime = true;
  File timeFile;
  size_t noResults = 1000;
  size_t minPeriod = 3;
  size_t maxPeriod = size_t.max;
  size_t periodStep = 3;
  size_t noThreads = 1;
  bool printConfig = false;  
  Algo algo = Algo.standard;  
}

string fileName( File file ) {
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
  with( cfg.outFile ) {
    writeln( "-------------------------------------------------" );
    writeln( "Configuration:" );
    
    writeln( "Verbosity level: ", cfg.verbosity );
    writeln( "Sequences file: ", cfg.sequencesFile.fileName() );
    
    writeln( "Print results: ", cfg.printResults );
    writeln( "Number of results: ", cfg.noResults );
    writeln( "Results file: ", cfg.resFile.fileName() );
    
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


/**
  This function will get the arguments from the command line and initialize
  the configuration accordingly. When this function throws, the main program
  should not consider the configuration in a usable state and therefore
  abort.
  
  This function not only throws on error, but also if the user asked for the
  help menu (-h).
*/
void parse( ref Config cfg, string[] tokens ) {
  //Runtime defaults.
  cfg.outFile = stdout;
  
  auto noResults = Flag.value( "--nr", "Number of results to keep in memory. Default is " ~ cfg.noResults.to!string() ~ ".", cfg.noResults );
  auto minPeriod = Flag.value( "--min", "Minimum period length. Default is " ~ cfg.minPeriod.to!string() ~ ".", cfg.minPeriod );
  auto maxPeriod = 
    Flag.value( 
      "--max",
      "Maximum period length. Default is " ~ cfg.minPeriod.to!string() ~ ". The mid sequence position is used if it is lower than this value.",
      cfg.maxPeriod 
    );
  auto periodStep = 
    Flag.value( 
      "--step",
      "Period step. The minimum period length MUST be set to a multiple of this value. The default is " ~ cfg.periodStep.to!string() ~ ".",
      cfg.periodStep 
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

  
  if( tokens[ 1 ] == "batch" ) {
  
    
  
  } else {
    cfg.resFile = stdout;  
    cfg.timeFile = stdout;
    
    auto parser = Parser( tokens, "N/A" );  
    
    auto seqFile = Flag.file( "-s", "Sequences file. This flag is mandatory.", cfg.sequencesFile, "r" );
    auto outFile = Flag.file( "--of", "Output file. This is where the program emits statements. Default is stdout.", cfg.outFile, "w" );
    auto resFile = Flag.file( "--rf", "Results file. This is where the program prints the results. Default is stdout.", cfg.resFile, "w" );
    auto timeFile = Flag.file( "--tf", "Time file. This is where the time will be printed. Default is stdout.", cfg.timeFile, "w" );
    
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
      periodStep,
      printConfig,
      algo      
    );
    
    parser.mandatory( seqFile );
    parser.mutuallyExclusive( printResults, resFile );
    parser.mutuallyExclusive( printTime, timeFile );
    
    parser.parse();    
  }
  
  //The minimum pattern length must be below the maximum pattern length.
  enforce( cfg.minPeriod <= cfg.maxPeriod, "The minimum period value: " ~ cfg.minPeriod.to!string() ~ " is above the maximum: " ~ cfg.maxPeriod.to!string() );
  //Not sure it's worth giving the user control over this. It has to be a period of three or 1...
  enforce( ( cfg.minPeriod % cfg.periodStep ) == 0, "The minimum period value: " ~ cfg.minPeriod.to!string ~ " is not a multiple of the period step: " ~ cfg.periodStep.to!string );
  
  if( cfg.printConfig ) {
    cfg.print();
  }  
}