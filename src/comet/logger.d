/**
  Module offering facilities for automating the usage of verbosity with files.
*/
module comet.logger;

import comet.typecons;

import std.stdio;
import std.algorithm;
import std.typecons;

/**
  A logger is a wrapper around an output file that controls what gets sent to the file based on a
  maximum verbosity accepted and a message verbosity (per print). Therefore, a logger who accepts
  messages of verbosity up to 4 does not print any messages with a verbosity of 5 or higher.
  
  Ex:
    auto logger = logger( stdout, 4 );
    logger.logln( 4, "You see this" );
    logger.log( 5, "But this does not get writtent );
*/
struct Logger {

private:

  File _out;          //The wrapped output.
  int _maxVerbosity;  //The maximum verbosity accepted, inclusive.
    
  this( typeof( _out ) outFile, typeof( _maxVerbosity ) maxV ) {
  
    _out = outFile;
    _maxVerbosity = maxV;    
  
  }
  
public:

  /**
    Matches any call like write, writeln, writef, etc... that starts with write. The difference is
    the expected calls here replace the "write" prefix with "log". So:
      log.logln( 0, "blabla" ) calls writeln on the loggers wrapped file.
      log.writeln does not compile.
  */
  auto opDispatch( string s, T... )( int messageVerbosity, T args ) if( s.startsWith( "log" ) ) {
  
    if( messageVerbosity <= _maxVerbosity ) {
    
      mixin( identifier!_out ~ ".write" ~ s[ 3 .. $ ] )( args );
    
    }
  
  }  
  
}

/**
  Factory function for loggers.
*/
auto logger( T... )( T args ) {

  return Logger( args );

}