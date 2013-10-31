module comet.cli.exceptions;

import comet.cli.arguments;

import std.exception;
import std.range;
import std.conv;
import std.string;


package:
/**
  Exception specific to flags expecting arguments.
  If the expected count is lower than what is actually provided on the command line,
  then this exception should be thrown.
*/
class MissingArgumentsException: Exception {
  this( size_t noArgs ) in {
    assert( 0 < noArgs, "a missing argument exception requires that at least 1 argument is missing, not: " ~ noArgs.to!string );
  } body {
    super( "expected " ~ noArgs.to!string ~ " argument" ~ ( 1 == noArgs ? "" : "s" ) );
  }  
}

/**
  Checks that the tokens provided hold enough arguments for the flag.
  Throws a standard exception otherwise (with a standard error message).
*/
void enforceEnoughArgs( string[] tokens, size_t noArgs ) {
  enforce( noArgs <= tokens.length, new MissingArgumentsException( noArgs ) );
}

/**
  Exception thrown when there are unrecognized tokens on the command line and they 
  were not expected.
*/
class UnrecognizedTokens: Exception {
  this( Range )( Range tokens ) if( isForwardRange!Range ) in {
    assert( !tokens.empty, "an unrecognized tokens exception requires at least one token" );
  } body {
    super( "unrecognized tokens: " ~ tokens.to!string );
  }
}

/**
  Verifies that the slice passed is empty, otherwise throws an exception.
*/
void enforceNoUnrecognizedTokens( Range )( Range unrecognizedTokens ) if( isForwardRange!Range ) {
  enforce( unrecognizedTokens.empty, new UnrecognizedTokens( unrecognizedTokens ) );
}

/**
  Exception thrown when the help menu has been requested by the user.
*/
class HelpMenuRequested: Exception {
  this() { super( "help menu requested" ); }
}