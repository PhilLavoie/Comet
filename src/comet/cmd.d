/**
  Command line interface of the program.
  It is responsible for setting up the flags and parsing the user's
  input, guaranteeing a usable state for the system.
*/
module comet.cmd;

import comet.config;

import deimos.flags;

import std.exception;
import std.conv;

void parse( string[] tokens, ref Config cfg ) {
  Parser parser;
  parser.file( "-s", "Sequences file. This flag is mandatory.", cfg.sequencesFile, "r" );
  parser.value( "--nr", "Number of results of keep in memory. Default is " ~ cfg.noResults.to!string() ~ ".", cfg.noResults );
  parser.value( "--min", "Minimum period length. Default is " ~ cfg.minPeriod.to!string() ~ ".", cfg.minPeriod );
  parser.value( "--max", "Maximum period length. Default is " ~ cfg.minPeriod.to!string() ~ ". The mid sequence position is used if it is lower than this value.", cfg.maxPeriod );
  parser.value( 
    "--step",
    "Period step. It is highly recommended that the minimum period length be set to a multiple of this value. The default is " ~ cfg.periodStep.to!string() ~ ".",
    cfg.periodStep 
  );
  parser.value( "-v", "Verbosity level. Default is " ~ cfg.verbosity.to!string ~ ".", cfg.verbosity );
  
  auto args = parser.parse( tokens );
  
  enforce( args is null || !args.length, "Unexpected arguments: " ~ args.to!string() );
  enforce( cfg.sequencesFile.isOpen, "User must provide the sequences file." );
  enforce( cfg.minPeriod <= cfg.maxPeriod, "The minimum period value: " ~ cfg.minPeriod.to!string() ~ " is above the maximum: " ~ cfg.maxPeriod.to!string() );
}

