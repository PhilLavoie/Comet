/**
  This module provides the formal definition of what a converter is.
  It also has multiple predefined converters for ease of use.
*/
module comet.cli.converters;

import std.conv: to;
import std.traits: isCallable, ReturnType, ParameterTypeTuple;
import std.exception: enforce;
import std.algorithm: startsWith, endsWith;
import std.stdio: File, stdin, stdout, stderr, dirEntries, SpanMode;
import std.path: dirSeparator;

/**
  A converter is a callable object that takes strings and returns a converted value. Note that
  it could: do nothing, return a constant.
*/
interface Converter( T ) {

  T opCall( string[] );
  
}

/**
  Returns true if the type or symbol implements the converter interface.
*/
package template isConverter( T... ) if( 1 == T.length ) {

  static if( isCallable!( T[ 0 ] ) && !is( ReturnType!T[ 0 ] == void ) && is( ParameterTypeTuple!( T[ 0 ] )[ 0 ] == string[] ) ) {
  
    enum isConverter = true;
    
  } else {
  
    enum isConverter = false;
    
  }
  
}

//Predefined converters for ease of use.

/**
  Returns a converter that always returns the same value, regardless of the parameters passed.
*/
auto constantConverter( T )( T value ) {

  return ( string[] ) => value;
  
}

/**
  Returns a converter that uses std.conv.to function to convert to the given type.
*/
auto toConverter( T )() {

  return ( string[] tokens ) => tokens[ 0 ].to!T();
  
}

/**
  Returns a converter that, in addition to using std.conv.to, it makes sure that the value is
  within given bounds. Bounds are inclusive.
*/
auto boundedConverter( T )( T min, T max ) {

  return ( string[] tokens ) { 
  
    auto t = tokens[ 0 ].to!T(); 
    enforce( min <= t, tokens[ 0 ] ~ " is under the minimum boundary allowed: " ~ min.to!string() );
    enforce( t <= max, tokens[ 0 ] ~ " is above the maximum boundary allowed: " ~ max.to!string() ); 
    return t;
    
  };
  
}

/**
  A converter that simply:
    1 - Guarantees the token is in the map.
    2 - Returns its associated values.
  This converter is very useful for enumerated values:
  enum Level {
    low,
    medium,
    highAsHell
  }
  auto conv = mappedConverter( [ "low": Level.low, "Okay": Level.medium, "IMissMyMomma": Level.highAsHell );
*/
auto mappedConverter( T )( in T[ string ] map ) {

  return ( string[] tokens ) {
  
    string temp = tokens[ 0 ];
    enforce( temp in map, temp ~ " is not one of possible values: " ~ map.keys.to!string );
    return map[ temp ];
    
  };
  
}

/**
  A converter that opens a file with the given mode. It supports those constants:
  stdout, stdin and stderr.
*/
auto fileConverter( string mode ) {

  return ( string[] tokens ) {
  
    if( tokens[ 0 ] == "stdout" ) {
    
      enforce( !mode.startsWith( "r" ), "stdout is used as input with mode " ~ mode );
      return stdout;
      
    } else if( tokens[ 0 ] == "stderr" ) {
    
      enforce( !mode.startsWith( "r" ), "stderr is used as input with mode " ~ mode );
      return stderr;
      
    } else if( tokens[ 0 ] == "stdin" ) {
    
      enforce( mode.startsWith( "r" ), "stdin is used as output with mode " ~ mode );
      return stdin;
      
    } else {          
    
      return File( tokens[ 0 ], mode );
      
    } 
    
  };
  
}

/**
  A converter that makes sure that the received token is a directory. It also guarantees
  that the returned string ends with a directory separator, ensuring the format on the client
  end.
*/
auto dirConverter() {

  return ( string[] tokens ) {
  
    auto dir = tokens[ 0 ];
    auto makeSure = dirEntries( dir, SpanMode.shallow ); //This will throw if if is not a dir.

    if( dir.endsWith( dirSeparator ) ) {
      return dir;
    }    
    return dir ~ dirSeparator;
    
  };
  
}