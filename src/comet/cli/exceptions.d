module comet.cli.exceptions;

import comet.cli.arguments;

import std.exception;
import std.range;
import std.conv;
import std.string;

/**
  This is the top level exception thrown by the parser when something happened. This is thrown when the parser has discovered
  an error internally. It is thrown only if the error has been handled, so the client should just catch that exception specifically
  and stop execution. Any other exception thrown by the parser is worth consulting though.
  If the internal error was an exception, then when this gets thrown, its next is set to the culprit.
*/
class AbortExecution: Exception {

  package this() {
  
    super( "" );
    
  }
  
  package this( Exception next ) {
    
    this();
    this.next = next;
  
  }
  
}

/**
  Exception specific to flags expecting arguments.
  If the expected count is lower than what is actually provided on the command line,
  then this exception should be thrown.
*/
class MissingArgumentsException: Exception {

  package this( size_t noArgs ) in {
  
    assert( 0 < noArgs, "a missing argument exception requires that at least 1 argument is missing, not: " ~ noArgs.to!string );
    
  } body {
  
    super( "expected " ~ noArgs.to!string ~ " argument" ~ ( 1 == noArgs ? "" : "s" ) );
    
  } 
  
}

/**
  Checks that the tokens provided hold enough arguments for the flag.
  Throws a standard exception otherwise (with a standard error message).
  
  It is highly recommended to use this function for parsers when they extract
  their argument to keep a standardized way of handling errors.
*/
void enforceEnoughArgs( string[] tokens, size_t noArgs ) {

  enforce( noArgs <= tokens.length, new MissingArgumentsException( noArgs ) );
  
}

/**
  Exception thrown when there are unrecognized tokens on the command line and they 
  were not expected.
*/
class UnrecognizedTokens: Exception {
  
  package this( Range )( Range tokens ) if( isForwardRange!Range ) in {
  
    assert( !tokens.empty, "an unrecognized tokens exception requires at least one token" );
    
  } body {
  
    super( "unrecognized tokens: " ~ tokens.to!string );
    
  }
  
  package this( T )( string token ) if( is( T == string ) ) in {
  
    assert( token.length, "passed an empty token as unrecognized" );    
    
  } body {
  
    super( "unrecognized token: " ~ token );
    
  }
  
}

/**
  Verifies that the slice passed is empty, otherwise throws an exception.
*/
package void enforceNoUnrecognizedTokens( Range )( Range unrecognizedTokens ) if( isForwardRange!Range ) {

  enforce( unrecognizedTokens.empty, new UnrecognizedTokens( unrecognizedTokens ) );
  
}

/**
  Exception thrown when the help menu has been requested by the user.
*/
class HelpMenuRequested: Exception {

  package this() { super( "help menu requested" ); }
  
}