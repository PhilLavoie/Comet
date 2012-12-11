/**
  Command line interface of the program.
  It is responsible for setting up the flags and parsing the user's
  input, guaranteeing a usable state for the system.
*/
module comet.config;

import deimos.flags;

import std.exception;
import std.conv;
import std.stdio;

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
  ubyte verbosity = 0;
  bool printConfig = false;
  bool printTime = false;
  bool usePatterns = false;
  bool useCache = false; 
  bool useCachePatterns = false;
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
  Parser parser;
  bool help = false;
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
  parser.trigger( "--patterns", "Use a pattern matching optimization that avoids cost recalculation of already visited pattern.", cfg.usePatterns );
  parser.trigger( "--cache", "Use a cache optimization that reuse already calculated cost for each period.", cfg.useCache );
  parser.trigger( "--cache-patterns", "Use both optimizations to calculate duplication costs.", cfg.useCachePatterns );
  parser.trigger( "-h", "Prints this menu.", help );
  auto args = parser.parse( tokens );
  
  //If help is needed, the rest of the arguments are not checked.
  if( help ) { 
    parser.printHelp( "comet -s <sequencesFile> [ options ]" );
    throw new Exception( "Print help menu" );
  }
  //We don't expect any arguments but those used on flags.
  enforce( args is null || !args.length, "Unexpected arguments: " ~ args.to!string() );
  //Sequence file is mandatory.
  enforce( cfg.sequencesFile.isOpen, "User must provide the sequences file." );  
  enforce( cfg.minPeriod <= cfg.maxPeriod, "The minimum period value: " ~ cfg.minPeriod.to!string() ~ " is above the maximum: " ~ cfg.maxPeriod.to!string() );
  enforce( ( cfg.minPeriod % cfg.periodStep ) == 0, "The minimum period value: " ~ cfg.minPeriod.to!string ~ " is not a multiple of the period step: " ~ cfg.periodStep.to!string );
  //Only one type of optimization can be used at a time.
  enforce( 
    ( !cfg.useCache && !cfg.usePatterns && !cfg.useCachePatterns ) ||
    (  cfg.useCache && !cfg.usePatterns && !cfg.useCachePatterns ) ||
    ( !cfg.useCache &&  cfg.usePatterns && !cfg.useCachePatterns ) ||
    ( !cfg.useCache && !cfg.usePatterns && cfg.useCachePatterns ) 
  );
  
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
  writeln( "Use patterns: ", cfg.usePatterns );
  writeln( "Use cache: ", cfg.useCache );
  writeln( "Use both cache and patterns: ", cfg.useCachePatterns );
  writeln( "-------------------------------------------------" );
}

