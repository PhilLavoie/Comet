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
  size_t noResults = 1000;
  size_t minPeriod = 3;
  size_t maxPeriod = size_t.max;
  size_t periodStep = 3;
  size_t noThreads = 1;
  ubyte verbosity = 0;
  bool printConfig = false;
  bool printTime = false;
  Algo algo = Algo.standard;  
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
  auto parser = Parser( tokens, "N/A" );
  
  parser.file( "-s", "Sequences file. This flag is mandatory.", cfg.sequencesFile, "r" );
  parser.value( "--nr", "Number of results of keep in memory. Default is " ~ cfg.noResults.to!string() ~ ".", cfg.noResults );
  parser.value( "--min", "Minimum period length. Default is " ~ cfg.minPeriod.to!string() ~ ".", cfg.minPeriod );
  parser.value( "--max", "Maximum period length. Default is " ~ cfg.minPeriod.to!string() ~ ". The mid sequence position is used if it is lower than this value.", cfg.maxPeriod );
  parser.value( 
    "--step",
    "Period step. The minimum period length MUST be set to a multiple of this value. The default is " ~ cfg.periodStep.to!string() ~ ".",
    cfg.periodStep 
  );
  parser.value( "-v", "Verbosity level. Default is " ~ cfg.verbosity.to!string ~ ".", cfg.verbosity );
  parser.trigger( "--print-config", "Prints the used configuration before starting the process if the flag is present.", cfg.printConfig );
  parser.trigger( "--print-time", "Prints the execution time.", cfg.printTime );
  parser.mapped( 
    "--algo", 
    "Sets the duplication cost calculation algorithm. Possible values are \"standard\", \"cache\", \"patterns\" and \"cache-patterns\".", 
    cfg.algo,
    algosByStrings
  );
  parser.parse();
  
  //Sequence file is mandatory.
  enforce( cfg.sequencesFile.isOpen, "User must provide the sequences file." );  
  enforce( cfg.minPeriod <= cfg.maxPeriod, "The minimum period value: " ~ cfg.minPeriod.to!string() ~ " is above the maximum: " ~ cfg.maxPeriod.to!string() );
  enforce( ( cfg.minPeriod % cfg.periodStep ) == 0, "The minimum period value: " ~ cfg.minPeriod.to!string ~ " is not a multiple of the period step: " ~ cfg.periodStep.to!string );
  
  if( cfg.printConfig ) {
    printConfig( cfg );
  }  
}

/**
  Prints the program configuration to the standard output.
  Typically, it is to be used on demand by the user.
*/
void printConfig( ref Config cfg ) {
  writeln( "-------------------------------------------------" );
  writeln( "Configuration:" );
  writeln( "Sequences file: ", cfg.sequencesFile.name );
  writeln( "Number of results: ", cfg.noResults );
  writeln( "Minimum period: ", cfg.minPeriod );
  writeln( "Maximum period: ", cfg.maxPeriod );
  writeln( "Period step: ", cfg.periodStep );
  writeln( "Verbosity: ", cfg.verbosity );
  writeln( "Print configuration: ", cfg.printConfig );  
  writeln( "Print time: ", cfg.printTime );
  writeln( "Algorithm: ", algoStrings[ cfg.algo ] );
  writeln( "-------------------------------------------------" );
}

