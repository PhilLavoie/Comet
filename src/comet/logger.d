module comet.logger;

import comet.meta;

import std.stdio;
import std.algorithm;
import std.typecons;

struct Logger {

private:

  File _out;
  int _maxVerbosity;
    
  this( typeof( _out ) outFile, typeof( _maxVerbosity ) maxV ) {
  
    _out = outFile;
    _maxVerbosity = maxV;    
  
  }
  
public:

  auto opDispatch( string s, T... )( int messageVerbosity, T args ) if( s.startsWith( "log" ) ) {
  
    if( messageVerbosity <= _maxVerbosity ) {
    
      mixin( identifier!_out ~ ".write" ~ s[ 3 .. $ ] )( args );
    
    }
  
  }
  
  auto opDispatch( string s, T... )( T args ) if( !s.startsWith( "log" ) ) {
    
    return mixin( identifier!_out ~ "." ~ s )( args );
  
  }  
  
}

auto logger( T... )( T args ) {

  return Logger( args );

}

unittest {
  
  auto log = logger( stdout, 1 );
  
  debug( logger ) {  
    log.logln( int.min, "you will always see this" );
    log.logln( 1, "you see this now" );
    log.logln( 2, "but you don't see this" );
  }

}